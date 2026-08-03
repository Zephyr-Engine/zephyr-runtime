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

pub const TextureFormat = enum {
    rgba8,
    depth24_stencil8,
};

pub const FramebufferDesc = struct {
    extent: Extent2D,
    color_format: TextureFormat = .rgba8,
    depth_stencil_format: ?TextureFormat = .depth24_stencil8,
};

const Framebuffer = @This();

impl: *anyopaque,
extent: Extent2D,
