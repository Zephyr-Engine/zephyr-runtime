const std = @import("std");

const Device = @import("rhi/device.zig");
const OpenGLDevice = @import("opengl/device.zig");

pub const Backend = enum {
    opengl,
};

pub fn init(allocator: std.mem.Allocator, backend: Backend) !Device {
    return switch (backend) {
        .opengl => OpenGLDevice.init(allocator),
    };
}

test "OpenGL device satisfies the complete RHI vtable" {
    var device = try init(std.testing.allocator, .opengl);
    device.deinit();
}
