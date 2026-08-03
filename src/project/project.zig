const std = @import("std");
const zimp = @import("zimp");

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
