const std = @import("std");
const zimp = @import("zimp");

const scene = zimp.scene;

const Project = @This();

manifest: zimp.ProjectManifest,
root_dir: std.Io.Dir,

pub fn watchAssets(self: *const Project, allocator: std.mem.Allocator, io: std.Io) !*zimp.WatchHandle {
    return zimp.WatchHandle.start(
        allocator,
        io,
        &self.manifest,
        self.root_dir,
        .{},
        .{},
    );
}

pub fn stopWatchingAssets(_: *Project, handle: *zimp.WatchHandle) void {
    handle.stop();
}

pub fn deinit(self: *Project, allocator: std.mem.Allocator, io: std.Io) void {
    self.manifest.deinit(allocator);
    self.root_dir.close(io);
}

pub fn loadScene(self: *const Project, allocator: std.mem.Allocator, io: std.Io, path: []const u8) !zimp.scene.SceneDocument {
    const bytes = try self.root_dir.readFileAlloc(
        io,
        path,
        allocator,
        .limited(scene.json_codec.max_scene_bytes),
    );
    defer allocator.free(bytes);

    if (std.mem.startsWith(u8, bytes, scene.binary_codec.magic)) {
        return try scene.binary_codec.decode(allocator, bytes);
    }

    return try scene.json_codec.decode(allocator, bytes);
}

pub fn loadDefaultScene(self: *const Project, allocator: std.mem.Allocator, io: std.Io) !zimp.scene.SceneDocument {
    const path = self.manifest.default_scene orelse return error.DefaultSceneNotFound;
    return self.loadScene(allocator, io, path);
}
