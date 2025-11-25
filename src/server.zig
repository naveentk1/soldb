const std = @import("std");
const net = std.net;

const Database = struct {
    allocator: std.mem.Allocator,
    data: std.StringHashMap([]const u8),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) Database {
        return .{
            .allocator = allocator,
            .data = std.StringHashMap([]const u8).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Database) void {
        var it = self.data.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.data.deinit();
    }

    pub fn set(self: *Database, key: []const u8, value: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        if (self.data.get(key)) |old_value| {
            self.allocator.free(old_value);
        }

        try self.data.put(key_copy, value_copy);
    }

    pub fn get(self: *Database, key: []const u8) !?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.data.get(key)) |value| {
            return try self.allocator.dupe(u8, value);
        }
        return null;
    }

    pub fn del(self: *Database, key: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.data.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value);
            return true;
        }
        return false;
    }

    pub fn exists(self: *Database, key: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.data.contains(key);
    }

    pub fn count(self: *Database) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.data.count();
    }
};

fn handleClient(db: *Database, conn: net.Server.Connection, allocator: std.mem.Allocator) !void {
    defer conn.stream.close();
    
    var buf: [4096]u8 = undefined;
    
    while (true) {
        const bytes_read = conn.stream.read(&buf) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        
        if (bytes_read == 0) break;
        
        const command = std.mem.trim(u8, buf[0..bytes_read], &std.ascii.whitespace);
        var response = try std.ArrayList(u8).initCapacity(allocator, 256);
        defer response.deinit(allocator);
        
        var parts = std.mem.splitScalar(u8, command, ' ');
        const cmd = parts.next() orelse {
            try response.appendSlice(allocator, "-ERR empty command\n");
            _ = try conn.stream.write(response.items);
            continue;
        };
        
        if (std.mem.eql(u8, cmd, "SET")) {
            const key = parts.next() orelse {
                try response.appendSlice(allocator, "-ERR missing key\n");
                _ = try conn.stream.write(response.items);
                continue;
            };
            const value = parts.rest();
            if (value.len == 0) {
                try response.appendSlice(allocator, "-ERR missing value\n");
                _ = try conn.stream.write(response.items);
                continue;
            }
            
            try db.set(key, value);
            std.debug.print("[SET] key=\"{s}\" value=\"{s}\"\n", .{key, value});
            try response.appendSlice(allocator, "+OK\n");
        }
        else if (std.mem.eql(u8, cmd, "GET")) {
            const key = parts.next() orelse {
                try response.appendSlice(allocator, "-ERR missing key\n");
                _ = try conn.stream.write(response.items);
                continue;
            };
            
            if (try db.get(key)) |value| {
                defer allocator.free(value);
                std.debug.print("[GET] key=\"{s}\" -> \"{s}\"\n", .{key, value});
                try response.appendSlice(allocator, "$");
                try response.writer(allocator).print("{d}", .{value.len});
                try response.appendSlice(allocator, "\n");
                try response.appendSlice(allocator, value);
                try response.appendSlice(allocator, "\n");
            } else {
                std.debug.print("[GET] key=\"{s}\" -> (nil)\n", .{key});
                try response.appendSlice(allocator, "$-1\n");
            }
        }
        else if (std.mem.eql(u8, cmd, "DEL")) {
            const key = parts.next() orelse {
                try response.appendSlice(allocator, "-ERR missing key\n");
                _ = try conn.stream.write(response.items);
                continue;
            };
            
            const deleted = db.del(key);
            std.debug.print("[DEL] key=\"{s}\" -> {any}\n", .{key, deleted});
            if (deleted) {
                try response.appendSlice(allocator, ":1\n");
            } else {
                try response.appendSlice(allocator, ":0\n");
            }
        }
        else if (std.mem.eql(u8, cmd, "EXISTS")) {
            const key = parts.next() orelse {
                try response.appendSlice(allocator, "-ERR missing key\n");
                _ = try conn.stream.write(response.items);
                continue;
            };
            
            const exists = db.exists(key);
            std.debug.print("[EXISTS] key=\"{s}\" -> {any}\n", .{key, exists});
            if (exists) {
                try response.appendSlice(allocator, ":1\n");
            } else {
                try response.appendSlice(allocator, ":0\n");
            }
        }
        else if (std.mem.eql(u8, cmd, "PING")) {
            std.debug.print("[PING]\n", .{});
            try response.appendSlice(allocator, "+PONG\n");
        }
        else if (std.mem.eql(u8, cmd, "DBSIZE")) {
            const size = db.count();
            std.debug.print("[DBSIZE] -> {any}\n", .{size});
            try response.appendSlice(allocator, ":");
            try response.writer(allocator).print("{d}", .{size});
            try response.appendSlice(allocator, "\n");
        }
        else if (std.mem.eql(u8, cmd, "QUIT")) {
            try response.appendSlice(allocator, "+OK\n");
            _ = try conn.stream.write(response.items);
            break;
        }
        else {
            try response.appendSlice(allocator, "-ERR unknown command '");
            try response.appendSlice(allocator, cmd);
            try response.appendSlice(allocator, "'\n");
        }
        
        _ = try conn.stream.write(response.items);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var db = Database.init(allocator);
    defer db.deinit();
    
    // Change the port here (default: 6379)
    const PORT: u16 = 6969;
    const address = try net.Address.parseIp("127.0.0.1", PORT);
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();
    
    std.debug.print("\n", .{});
    std.debug.print("███████╗ ██████╗ ██╗     ██████╗ ██████╗ \n", .{});
    std.debug.print("██╔════╝██╔═══██╗██║     ██╔══██╗██╔══██╗\n", .{});
    std.debug.print("███████╗██║   ██║██║     ██║  ██║██████╔╝\n", .{});
    std.debug.print("╚════██║██║   ██║██║     ██║  ██║██╔══██╗\n", .{});
    std.debug.print("███████║╚██████╔╝███████╗██████╔╝██████╔╝\n", .{});
    std.debug.print("╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚═════╝ \n", .{});
    std.debug.print("\n", .{});
    std.debug.print("SolDB v1.0.0 - In-Memory Database Server\n", .{});
    std.debug.print("Port: {d}\n", .{PORT});
    std.debug.print("\n", .{});
    std.debug.print("⚡ Server is ready to accept connections\n", .{});
    std.debug.print("💡 Run 'sol-cli' in another terminal to connect\n", .{});
    std.debug.print("\n", .{});
    
    while (true) {
        const conn = try server.accept();
        std.debug.print("[{any}] Client connected from {any}\n", .{ std.time.timestamp(), conn.address });
        
        const thread = try std.Thread.spawn(.{}, handleClient, .{ &db, conn, allocator });
        thread.detach();
    }
}