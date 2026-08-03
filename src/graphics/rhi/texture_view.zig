const TextureView = @This();

/// A non-owning view. It remains valid only while its parent texture or
/// framebuffer attachment exists.
impl: *const anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    bind: *const fn (impl: *const anyopaque, unit: u16) void,
    nativeId: *const fn (impl: *const anyopaque) u32,
};

pub fn bind(self: TextureView, unit: u16) void {
    self.vtable.bind(self.impl, unit);
}

/// Interop for APIs that cannot consume an RHI texture view directly.
pub fn nativeId(self: TextureView) u32 {
    return self.vtable.nativeId(self.impl);
}
