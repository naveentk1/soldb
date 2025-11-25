const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("soldb", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // Server executable (sol-server) - uses server.zig
    const server_exe = b.addExecutable(.{
        .name = "sol-server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/server.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "soldb", .module = mod },
            },
        }),
    });
    b.installArtifact(server_exe);

    // CLI executable (sol-cli) - uses main.zig
    const cli_exe = b.addExecutable(.{
        .name = "sol-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),  // This is your CLI
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "soldb", .module = mod },
            },
        }),
    });
    b.installArtifact(cli_exe);

    // Run steps for server
    const run_server_step = b.step("run-server", "Run the server");
    const run_server_cmd = b.addRunArtifact(server_exe);
    run_server_step.dependOn(&run_server_cmd.step);
    run_server_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_server_cmd.addArgs(args);
    }

    // Run steps for CLI
    const run_cli_step = b.step("run-cli", "Run the CLI");
    const run_cli_cmd = b.addRunArtifact(cli_exe);
    run_cli_step.dependOn(&run_cli_cmd.step);
    run_cli_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cli_cmd.addArgs(args);
    }

    // Tests
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const server_tests = b.addTest(.{
        .root_module = server_exe.root_module,
    });
    const run_server_tests = b.addRunArtifact(server_tests);

    const cli_tests = b.addTest(.{
        .root_module = cli_exe.root_module,
    });
    const run_cli_tests = b.addRunArtifact(cli_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_server_tests.step);
    test_step.dependOn(&run_cli_tests.step);
}
