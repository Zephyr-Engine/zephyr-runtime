const Texture = @import("rhi/texture.zig");
const TextureView = @import("rhi/texture_view.zig");
const Device = @import("rhi/device.zig");

const TextureAsset = @This();

view: TextureView,
texture: Texture,
device: *Device,

pub fn deinit(self: *TextureAsset) void {
    self.device.destroyTexture(&self.texture);
}
