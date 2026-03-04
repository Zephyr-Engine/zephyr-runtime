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

    const mod = b.addModule("zephyr_runtime", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    mod.linkLibrary(glfw_dep.artifact("glfw"));
    mod.linkLibrary(glad_dep.artifact("glad"));
}
