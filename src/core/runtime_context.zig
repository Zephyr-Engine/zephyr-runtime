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

test "RenderViewport aspect guards against zero height" {
    try std.testing.expectApproxEqAbs(@as(f32, 16.0 / 9.0), (RenderViewport{ .width = 1920, .height = 1080 }).aspect(), 0.0001);
    try std.testing.expectEqual(@as(f32, 640.0), (RenderViewport{ .width = 640, .height = 0 }).aspect());
}
