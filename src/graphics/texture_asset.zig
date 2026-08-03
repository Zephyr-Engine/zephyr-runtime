const Texture = @import("rhi/texture.zig");
const TextureView = @import("rhi/texture_view.zig");
const Sampler = @import("rhi/sampler.zig");
const Device = @import("rhi/device.zig");

const TextureAsset = @This();
texture: Texture,
view: TextureView,
sampler: Sampler,
device: *Device,

pub fn deinit(self: *TextureAsset) void {
    self.device.destroySampler(&self.sampler);
    self.device.destroyTexture(&self.texture);
}
