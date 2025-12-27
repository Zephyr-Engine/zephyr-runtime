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
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    runtime_mod.linkLibrary(glfw_dep.artifact("glfw"));
    runtime_mod.linkLibrary(glad_dep.artifact("glad"));

    // Add a check step to populate LSP data
    const check = b.step("check", "Check if the library compiles");
    const lib_check = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_check.linkLibrary(glfw_dep.artifact("glfw"));
    lib_check.linkLibrary(glad_dep.artifact("glad"));

    const check_compile = b.addObject(.{
        .name = "zephyr_runtime_check",
        .root_module = lib_check,
    });
    check.dependOn(&check_compile.step);
}
