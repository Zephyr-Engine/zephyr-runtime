const std = @import("std");

const log = @import("../core/log.zig");
const project_manifest = @import("manifest.zig");
const ProjectManifest = project_manifest.ProjectManifest;

pub const CreateProjectOptions = struct {
    name: []const u8,
    root_path: []const u8,
};

pub fn create(allocator: std.mem.Allocator, io: std.Io, opts: CreateProjectOptions) !ProjectManifest {
    const root_dir = try std.Io.Dir.openDirAbsolute(io, opts.root_path, .{});
    defer root_dir.close(io);

    return createInDir(allocator, io, root_dir, opts.name);
}

fn createInDir(allocator: std.mem.Allocator, io: std.Io, root_dir: std.Io.Dir, name: []const u8) !ProjectManifest {
    if (ProjectManifest.loadFromDir(allocator, io, root_dir, project_manifest.default_manifest_path)) |manifest| {
        return manifest;
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

    return manifest;
}

const testing = std.testing;

test "create returns existing manifest when manifest file already exists" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const first = try createInDir(testing.allocator, testing.io, tmp.dir, "First Project");
    defer first.deinit(testing.allocator);

    const second = try createInDir(testing.allocator, testing.io, tmp.dir, "Second Project");
    defer second.deinit(testing.allocator);

    try testing.expect(first.project_id.eql(second.project_id));
    try testing.expectEqualStrings("First Project", second.name);
}
