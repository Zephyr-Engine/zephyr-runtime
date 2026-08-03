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
