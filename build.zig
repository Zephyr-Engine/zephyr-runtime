const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const glfw_dep = b.dependency("glfw_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const glad_dep = b.dependency("zig_glad", .{
        .target = target,
        .optimize = optimize,
    });

    const runtime_mod = b.addModule("zephyr_runtime", .{
        .root_source_file = b.path("src/runtime/root.zig"),
        .target = target,
    });
    runtime_mod.linkLibrary(glfw_dep.artifact("glfw"));
    runtime_mod.linkLibrary(glad_dep.artifact("glad"));
}
