const std = @import("std");

const rhi_device = @import("../rhi/device.zig");
const RhiFramebuffer = @import("../rhi/framebuffer.zig");
const render_state = @import("render_state.zig");
const OpenGLFramebuffer = @import("framebuffer.zig");

const OpenGLDevice = @This();

allocator: std.mem.Allocator,

const vtable = rhi_device.VTable{
    .deinit = deinit,
    .createFramebuffer = createFramebuffer,
    .destroyFramebuffer = destroyFramebuffer,
    .resizeFramebuffer = resizeFramebuffer,
    .beginRenderPass = beginRenderPass,
    .endRenderPass = endRenderPass,
    .framebufferTextureId = framebufferTextureId,
};

pub fn init(allocator: std.mem.Allocator) !rhi_device {
    const self = try allocator.create(OpenGLDevice);
    self.* = .{ .allocator = allocator };

    return .{
        .impl = self,
        .vtable = &vtable,
    };
}

fn deinit(impl: *anyopaque) void {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    const allocator = self.allocator;
    allocator.destroy(self);
}

fn createFramebuffer(impl: *anyopaque, desc: RhiFramebuffer.FramebufferDesc) anyerror!RhiFramebuffer {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    const extent = desc.extent.normalized();

    const framebuffer = try self.allocator.create(OpenGLFramebuffer);
    errdefer self.allocator.destroy(framebuffer);

    framebuffer.* = try OpenGLFramebuffer.init(extent.width, extent.height);

    return .{
        .impl = framebuffer,
        .extent = extent,
    };
}

fn destroyFramebuffer(impl: *anyopaque, target: *RhiFramebuffer) void {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    const framebuffer: *OpenGLFramebuffer = @ptrCast(@alignCast(target.impl));

    framebuffer.deinit();
    self.allocator.destroy(framebuffer);
    target.* = undefined;
}

fn resizeFramebuffer(_: *anyopaque, target: *RhiFramebuffer, extent: RhiFramebuffer.Extent2D) anyerror!void {
    const normalized = extent.normalized();
    const framebuffer: *OpenGLFramebuffer = @ptrCast(@alignCast(target.impl));

    try framebuffer.resize(normalized.width, normalized.height);
    target.extent = normalized;
}

fn beginRenderPass(_: *anyopaque, info: rhi_device.RenderPassInfo) anyerror!void {
    switch (info.target) {
        .swapchain => |viewport| OpenGLFramebuffer.bindDefault(viewport.width, viewport.height),
        .framebuffer => |target| {
            const framebuffer: *const OpenGLFramebuffer = @ptrCast(@alignCast(target.impl));
            framebuffer.bind();
        },
    }

    render_state.begin(.{
        .color = info.color,
        .depth = info.depth,
    });
}

fn endRenderPass(_: *anyopaque) void {}

fn framebufferTextureId(_: *anyopaque, target: *const RhiFramebuffer) u32 {
    const framebuffer: *const OpenGLFramebuffer = @ptrCast(@alignCast(target.impl));
    return framebuffer.color_texture;
}
