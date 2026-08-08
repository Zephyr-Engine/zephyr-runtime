const ResourceHandle = @import("resource_handle.zig");
const Framebuffer = @import("framebuffer.zig");
const Texture = @import("texture.zig");

const TextureView = @This();

source: Source,

pub const Source = union(enum) {
    texture: ResourceHandle,
    framebuffer_color: ResourceHandle,
};

pub fn fromFramebuffer(framebuffer: Framebuffer) TextureView {
    return .{
        .source = .{ .framebuffer_color = framebuffer.handle },
    };
}

pub fn fromTexture(texture: Texture) TextureView {
    return .{ .source = .{ .texture = texture.handle } };
}

const testing = @import("std").testing;

test "fromTexture wraps the texture's handle as a texture source" {
    var owner: u32 = 0;
    const texture = Texture{
        .handle = .{ .owner = &owner, .index = 3, .generation = 1 },
        .extent = .{ .width = 4, .height = 4 },
        .format = .rgba8_unorm,
        .mip_count = 1,
    };

    const view = TextureView.fromTexture(texture);
    switch (view.source) {
        .texture => |handle| try testing.expect(handle.belongsTo(&owner)),
        .framebuffer_color => return error.UnexpectedSource,
    }
}

test "fromFramebuffer wraps the framebuffer's handle as a color source" {
    var owner: u32 = 0;
    const framebuffer = Framebuffer{
        .handle = .{ .owner = &owner, .index = 5, .generation = 2 },
        .extent = .{ .width = 8, .height = 8 },
        .color_format = .rgba8,
        .depth_stencil_format = null,
    };

    const view = TextureView.fromFramebuffer(framebuffer);
    switch (view.source) {
        .framebuffer_color => |handle| try testing.expect(handle.belongsTo(&owner)),
        .texture => return error.UnexpectedSource,
    }
}
