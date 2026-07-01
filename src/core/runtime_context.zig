const std = @import("std");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;

pub const RenderViewport = struct {
    width: u32 = 1,
    height: u32 = 1,

    pub fn aspect(self: RenderViewport) f32 {
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(@max(1, self.height)));
    }
};

pub const RuntimeContext = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    assets: *AssetManager,
    render_viewport: RenderViewport = .{},
};
