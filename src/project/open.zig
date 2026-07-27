const std = @import("std");
const zimp = @import("zimp");

const manifest_mod = zimp.project.manifest;
const ProjectManfiest = zimp.ProjectManifest;
const Project = @import("project.zig").Project;

pub const OpenProjectOptions = struct {
    root_path: []const u8,
};

pub fn open(allocator: std.mem.Allocator, io: std.Io, opts: OpenProjectOptions) !Project {
    if (!zimp.path.isAbsolute(opts.root_path)) {
        return error.ProjectRootMustBeAbsolute;
    }

    const root_dir = try std.Io.Dir.openDirAbsolute(io, opts.root_path, .{});
    errdefer root_dir.close(io);

    const manifest = try ProjectManfiest.loadFromDir(
        allocator,
        io,
        root_dir,
        manifest_mod.default_manifest_path,
    );

    return .{
        .manfiest = manifest,
        .root_dir = root_dir,
    };
}
