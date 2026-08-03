const ResourceHandle = @import("resource_handle.zig");

pub const Extent2D = struct {
    width: u32 = 1,
    height: u32 = 1,

    pub fn normalized(self: Extent2D) Extent2D {
        return .{
            .width = @max(1, self.width),
            .height = @max(1, self.height),
        };
    }
};

pub const ColorFormat = enum {
    rgba8,
    rgba16_float,
};

pub const DepthStencilFormat = enum {
    depth24_stencil8,
    depth32_float,
};

pub const FramebufferDesc = struct {
    extent: Extent2D,
    color_format: ColorFormat = .rgba8,
    depth_stencil_format: ?DepthStencilFormat = .depth24_stencil8,
};

const Framebuffer = @This();

handle: ResourceHandle,
extent: Extent2D,
color_format: ColorFormat,
depth_stencil_format: ?DepthStencilFormat,

test "framebuffer extents normalize zero dimensions" {
    const testing = @import("std").testing;
    try testing.expectEqual(Extent2D{ .width = 1, .height = 1 }, (Extent2D{ .width = 0, .height = 0 }).normalized());
}
