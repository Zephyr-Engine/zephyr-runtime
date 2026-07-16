const std = @import("std");

const log = @import("../core/log.zig");
const zimp = @import("zimp");

const project_manifest = @import("manifest.zig");
const ProjectManifest = project_manifest.ProjectManifest;
const Project = project_manifest.Project;

pub const CreateProjectOptions = struct {
    name: []const u8,
    root_path: []const u8,
};

pub fn create(allocator: std.mem.Allocator, io: std.Io, opts: CreateProjectOptions) !Project {
    if (!zimp.path.isAbsolute(opts.root_path)) {
        return error.ProjectRootMustBeAbsolute;
    }

    const root_dir = try std.Io.Dir.openDirAbsolute(io, opts.root_path, .{});

    return createInDir(allocator, io, root_dir, opts.name);
}

fn createInDir(allocator: std.mem.Allocator, io: std.Io, root_dir: std.Io.Dir, name: []const u8) !Project {
    errdefer root_dir.close(io);

    if (ProjectManifest.loadFromDir(allocator, io, root_dir, project_manifest.default_manifest_path)) |manifest| {
        return .{
            .manifest = manifest,
            .root_dir = root_dir,
        };
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }

    const project_name = try allocator.dupe(u8, name);

    const random_source: std.Random.IoSource = .{ .io = io };
    const manifest = ProjectManifest{
        .project_id = .v4(random_source.interface()),
        .name = project_name,
    };
    errdefer manifest.deinit(allocator);

    root_dir.createDirPath(io, manifest.generated_dir) catch |err| {
        log.err("Failed to create root manifest directory: {}", .{err});
        return err;
    };

    root_dir.createDirPath(io, manifest.assets_dir) catch |err| {
        log.err("Failed to create assets directory: {}", .{err});
        return err;
    };

    root_dir.createDirPath(io, manifest.scenes_dir) catch |err| {
        log.err("Failed to create scenes directory: {}", .{err});
        return err;
    };

    root_dir.createDirPath(io, manifest.cooked_assets_dir) catch |err| {
        log.err("Failed to create cooked assets directory: {}", .{err});
        return err;
    };

    manifest.save(allocator, io, root_dir) catch |err| {
        log.err("Failed to save manifest: {}", .{err});
        return err;
    };

    return .{
        .manifest = manifest,
        .root_dir = root_dir,
    };
}

const testing = std.testing;

test "create rejects relative project roots" {
    try testing.expectError(error.ProjectRootMustBeAbsolute, create(testing.allocator, testing.io, .{
        .root_path = ".",
        .name = "Relative Project",
    }));
}

test "create returns existing manifest when manifest file already exists" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const first_dir = try std.Io.Dir.openDir(tmp.dir, testing.io, ".", .{});
    var first = try createInDir(testing.allocator, testing.io, first_dir, "First Project");
    defer first.deinit(testing.allocator, testing.io);

    const second_dir = try std.Io.Dir.openDir(tmp.dir, testing.io, ".", .{});
    var second = try createInDir(testing.allocator, testing.io, second_dir, "Second Project");
    defer second.deinit(testing.allocator, testing.io);

    try testing.expect(first.manifest.project_id.eql(second.manifest.project_id));
    try testing.expectEqualStrings("First Project", second.manifest.name);
}
