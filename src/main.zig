const std = @import("std");
const net = std.net;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    _=allocator;
    // Change the port here to match your server (default: 6379)
    const PORT: u16 = 6969;
    const address = try net.Address.parseIp("127.0.0.1", PORT);
    const stream = try net.tcpConnectToAddress(address);
    defer stream.close();
    
    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════╗\n", .{});
    std.debug.print("║     SolDB CLI - Connected to          ║\n", .{});
    std.debug.print("║     127.0.0.1:{d}                    ║\n", .{PORT});
    std.debug.print("╚═══════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Commands: SET, GET, DEL, EXISTS, PING, DBSIZE, QUIT\n", .{});
    std.debug.print("\n", .{});
    
    var line_buf: [4096]u8 = undefined;
    var response_buf: [4096]u8 = undefined;
    
    while (true) {
        std.debug.print("soldb> ", .{});
        
        const bytes_read = std.posix.read(std.posix.STDIN_FILENO, &line_buf) catch |err| {
            std.debug.print("Error reading input: {}\n", .{err});
            break;
        };
        
        if (bytes_read == 0) break;
        
        const trimmed = std.mem.trim(u8, line_buf[0..bytes_read], &std.ascii.whitespace);
        
        if (trimmed.len == 0) continue;
        
        _ = try stream.write(trimmed);
        
        const response_bytes = try stream.read(&response_buf);
        if (response_bytes == 0) {
            std.debug.print("(connection closed)\n", .{});
            break;
        }
        
        const response = std.mem.trim(u8, response_buf[0..response_bytes], &std.ascii.whitespace);
        
        if (response.len > 0) {
            switch (response[0]) {
                '+' => std.debug.print("{s}\n", .{response[1..]}),
                '-' => std.debug.print("(error) {s}\n", .{response[1..]}),
                ':' => std.debug.print("(integer) {s}\n", .{response[1..]}),
                '$' => {
                    const newline_pos = std.mem.indexOfScalar(u8, response, '\n') orelse response.len;
                    const len_str = response[1..newline_pos];
                    const len = std.fmt.parseInt(i32, len_str, 10) catch -1;
                    if (len == -1) {
                        std.debug.print("(nil)\n", .{});
                    } else {
                        const value_start = newline_pos + 1;
                        if (value_start < response.len) {
                            std.debug.print("\"{s}\"\n", .{response[value_start..]});
                        }
                    }
                },
                else => std.debug.print("{s}\n", .{response}),
            }
        }
        
        if (std.mem.eql(u8, trimmed, "QUIT")) break;
    }
    
    std.debug.print("\n✨ Goodbye!\n\n", .{});
}