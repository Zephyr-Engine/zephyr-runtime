const std = @import("std");
const zimp = @import("zimp");

const project_manifest = @import("manifest.zig");
const ProjectManifest = project_manifest.ProjectManifest;
const Project = project_manifest.Project;

pub const OpenProjectOptions = struct {
    root_path: []const u8,
};

pub fn open(allocator: std.mem.Allocator, io: std.Io, opts: OpenProjectOptions) !Project {
    if (!zimp.path.isAbsolute(opts.root_path)) {
        return error.ProjectRootMustBeAbsolute;
    }

    const root_dir = try std.Io.Dir.openDirAbsolute(io, opts.root_path, .{});
    errdefer root_dir.close(io);

    const manifest = try ProjectManifest.loadFromDir(
        allocator,
        io,
        root_dir,
        project_manifest.default_manifest_path,
    );
    errdefer manifest.deinit(allocator);

    return .{
        .manifest = manifest,
        .root_dir = root_dir,
    };
}

const testing = std.testing;

test "open rejects relative project roots" {
    try testing.expectError(error.ProjectRootMustBeAbsolute, open(testing.allocator, testing.io, .{
        .root_path = ".",
    }));
}

test "open loads manifest from absolute project root" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const manifest: ProjectManifest = .{
        .name = "Opened Project",
        .project_id = .zero,
    };
    try manifest.save(testing.allocator, testing.io, tmp.dir);

    var real_path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const real_path_len = try tmp.dir.realPathFile(testing.io, ".", &real_path_buf);
    const root_path = real_path_buf[0..real_path_len];

    var project = try open(testing.allocator, testing.io, .{
        .root_path = root_path,
    });
    defer project.deinit(testing.allocator, testing.io);

    try testing.expectEqualStrings("Opened Project", project.manifest.name);
    try testing.expect(project.manifest.project_id.eql(.zero));
}
