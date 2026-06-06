const std = @import("std");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;

pub const RuntimeContext = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    assets: *AssetManager,
};
