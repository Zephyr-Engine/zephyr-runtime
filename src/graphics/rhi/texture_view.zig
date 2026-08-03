const ResourceHandle = @import("resource_handle.zig");
const Framebuffer = @import("framebuffer.zig");

const TextureView = @This();

handle: ResourceHandle,

pub fn fromFramebuffer(framebuffer: Framebuffer) TextureView {
    return .{
        .handle = framebuffer.handle,
    };
}
