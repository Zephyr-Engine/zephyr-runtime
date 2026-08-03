const std = @import("std");

const OpenGLDevice = @import("../opengl/device.zig");
const render_state = @import("../render_state.zig");
const Framebuffer = @import("framebuffer.zig");

pub const Backend = enum {
    opengl,
};

pub const RenderViewport = struct {
    width: u32 = 1,
    height: u32 = 1,

    pub fn aspect(self: RenderViewport) f32 {
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(@max(1, self.height)));
    }

    pub fn extent(self: RenderViewport) Framebuffer.Extent2D {
        return .{ .width = self.width, .height = self.height };
    }
};

pub const RenderTarget = union(enum) {
    swapchain: RenderViewport,
    framebuffer: *Framebuffer,

    pub fn viewport(self: RenderTarget) RenderViewport {
        return switch (self) {
            .swapchain => |value| value,
            .framebuffer => |value| .{
                .width = value.extent.width,
                .height = value.extent.height,
            },
        };
    }
};

pub const RenderPassInfo = struct {
    target: RenderTarget,
    color: ?render_state.ColorLoadOp = null,
    depth: ?render_state.DepthLoadOp = null,
};

const Device = @This();

impl: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    deinit: *const fn (impl: *anyopaque) void,
    createFramebuffer: *const fn (impl: *anyopaque, desc: Framebuffer.FramebufferDesc) anyerror!Framebuffer,
    destroyFramebuffer: *const fn (impl: *anyopaque, target: *Framebuffer) void,
    resizeFramebuffer: *const fn (impl: *anyopaque, target: *Framebuffer, extent: Framebuffer.Extent2D) anyerror!void,
    beginRenderPass: *const fn (impl: *anyopaque, info: RenderPassInfo) anyerror!void,
    endRenderPass: *const fn (impl: *anyopaque) void,
    framebufferTextureId: *const fn (impl: *anyopaque, target: *const Framebuffer) u32,
};

pub fn init(allocator: std.mem.Allocator, backend: Backend) !Device {
    return switch (backend) {
        .opengl => OpenGLDevice.init(allocator),
    };
}

pub fn deinit(self: *Device) void {
    self.vtable.deinit(self.impl);
    self.* = undefined;
}

pub fn createFramebuffer(self: *Device, width: u32, height: u32) anyerror!Framebuffer {
    return self.createFramebufferDesc(.{ .extent = .{ .width = width, .height = height } });
}

pub fn createFramebufferDesc(self: *Device, desc: Framebuffer.FramebufferDesc) anyerror!Framebuffer {
    return self.vtable.createFramebuffer(self.impl, desc);
}

pub fn destroyFramebuffer(self: *Device, target: *Framebuffer) void {
    self.vtable.destroyFramebuffer(self.impl, target);
}

pub fn resizeFramebuffer(self: *Device, target: *Framebuffer, extent: Framebuffer.Extent2D) anyerror!void {
    return self.vtable.resizeFramebuffer(self.impl, target, extent);
}

pub fn beginRenderPass(self: *Device, info: RenderPassInfo) anyerror!void {
    return self.vtable.beginRenderPass(self.impl, info);
}

pub fn endRenderPass(self: *Device) void {
    self.vtable.endRenderPass(self.impl);
}

pub fn framebufferTextureId(self: *Device, target: *const Framebuffer) u32 {
    return self.vtable.framebufferTextureId(self.impl, target);
}
