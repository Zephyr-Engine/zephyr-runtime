const std = @import("std");
const zimp = @import("zimp");

pub const addProjectCookStep = zimp.addProjectCookStep;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlm_dep = b.dependency("zlm", .{
        .target = target,
        .optimize = optimize,
    });

    const zimp_dep = b.dependency("zimp", .{
        .target = target,
        .optimize = optimize,
    });
    b.modules.put(b.graph.arena, b.dupe("zimp"), zimp_dep.module("zimp")) catch @panic("OOM");

    const zob_dep = b.dependency("zob", .{
        .target = target,
        .optimize = optimize,
    });

    const zcs_dep = b.dependency("zcs", .{
        .target = target,
        .optimize = optimize,
    });

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
    mod.addImport("zlm", zlm_dep.module("zlm"));
    mod.addImport("zimp", zimp_dep.module("zimp"));
    mod.addImport("zob", zob_dep.module("zob"));
    mod.addImport("zcs", zcs_dep.module("zcs"));

    const check = b.step("check", "Check if library compiles");
    const lib_check = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_check.linkLibrary(glfw_dep.artifact("glfw"));
    lib_check.linkLibrary(glad_dep.artifact("glad"));
    lib_check.addImport("zlm", zlm_dep.module("zlm"));
    lib_check.addImport("zimp", zimp_dep.module("zimp"));
    lib_check.addImport("zob", zob_dep.module("zob"));
    lib_check.addImport("zcs", zcs_dep.module("zcs"));

    const check_compile = b.addObject(.{
        .name = "zephyr_runtime_check",
        .root_module = lib_check,
    });

    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib_unit_tests.root_module.linkLibrary(glfw_dep.artifact("glfw"));
    lib_unit_tests.root_module.linkLibrary(glad_dep.artifact("glad"));
    lib_unit_tests.root_module.addImport("zlm", zlm_dep.module("zlm"));
    lib_unit_tests.root_module.addImport("zimp", zimp_dep.module("zimp"));
    lib_unit_tests.root_module.addImport("zob", zob_dep.module("zob"));
    lib_unit_tests.root_module.addImport("zcs", zcs_dep.module("zcs"));

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    check.dependOn(&check_compile.step);
}
