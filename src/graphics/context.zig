const Backend = @import("device_factory.zig").Backend;
const OpenGL = @import("opengl/context.zig");
const c = @import("../c.zig");

pub fn configure(backend: Backend, msaa_samples: u32) void {
    switch (backend) {
        .opengl => OpenGL.configure(msaa_samples),
    }
}

pub fn initialize(backend: Backend, window: c.Window, msaa_samples: u32) !void {
    switch (backend) {
        .opengl => try OpenGL.initialize(window, msaa_samples),
    }
}
