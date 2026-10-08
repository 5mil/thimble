const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const server = b.addExecutable(.{
        .name = "aol-server",
        .root_source_file = b.path("src/server.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(server);

    const run_step = b.step("run", "Run the America Online host");
    const run = b.addRunArtifact(server);
    run_step.dependOn(&run.step);

    const windows = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu });
    const client = b.addExecutable(.{
        .name = "AmericaOnline",
        .root_source_file = b.path("src/client.zig"),
        .target = windows,
        .optimize = optimize,
    });
    client.subsystem = .Windows;
    client.linkSystemLibrary("winhttp");
    b.installArtifact(client);
}
