const std = @import("std");

const log = @import("../core/log.zig");
const ProjectManifest = @import("manifest.zig").ProjectManifest;

pub const CreateProjectOptions = struct {
    name: []const u8,
    root_path: []const u8,
};

pub fn create(allocator: std.mem.Allocator, io: std.Io, opts: CreateProjectOptions) !ProjectManifest {
    const root_dir = try std.Io.Dir.openDirAbsolute(io, opts.root_path, .{});
    defer root_dir.close(io);

    const random_source: std.Random.IoSource = .{ .io = io };
    const manifest = ProjectManifest{
        .project_id = .v4(random_source.interface()),
        .name = opts.name,
    };

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
