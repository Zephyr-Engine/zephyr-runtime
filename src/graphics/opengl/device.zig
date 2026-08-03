const std = @import("std");

const rhi_device = @import("../rhi/device.zig");
const RhiFramebuffer = @import("../rhi/framebuffer.zig");
const RhiGraphicsPipeline = @import("../rhi/graphics_pipeline.zig");
const TextureView = @import("../rhi/texture_view.zig");
const render_state = @import("render_state.zig");
const OpenGLFramebuffer = @import("framebuffer.zig");
const OpenGLGraphicsPipeline = @import("graphics_pipeline.zig");

const OpenGLDevice = @This();

allocator: std.mem.Allocator,
next_pipeline_sort_key: u64 = 1,

const vtable = rhi_device.VTable{
    .deinit = deinit,
    .bindRenderTarget = bindRenderTarget,
    .createFramebuffer = createFramebuffer,
    .destroyFramebuffer = destroyFramebuffer,
    .resizeFramebuffer = resizeFramebuffer,
    .beginRenderPass = beginRenderPass,
    .endRenderPass = endRenderPass,
    .framebufferColorView = framebufferColorView,
    .createGraphicsPipeline = createGraphicsPipeline,
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

    framebuffer.* = try OpenGLFramebuffer.init(.{
        .extent = extent,
        .color_format = desc.color_format,
        .depth_stencil_format = desc.depth_stencil_format,
    });

    return .{
        .impl = framebuffer,
        .extent = extent,
        .color_format = desc.color_format,
        .depth_stencil_format = desc.depth_stencil_format,
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
    bindTarget(info.target);

    render_state.begin(.{
        .color = info.color,
        .depth = info.depth,
    });
}

fn bindRenderTarget(_: *anyopaque, target: rhi_device.RenderTarget) void {
    bindTarget(target);
}

fn bindTarget(target: rhi_device.RenderTarget) void {
    switch (target) {
        .swapchain => |viewport| OpenGLFramebuffer.bindDefault(viewport.width, viewport.height),
        .framebuffer => |framebuffer_target| {
            const framebuffer: *const OpenGLFramebuffer = @ptrCast(@alignCast(framebuffer_target.impl));
            framebuffer.bind();
        },
    }
}

fn endRenderPass(_: *anyopaque) void {}

const texture_view_vtable = TextureView.VTable{
    .bind = bindFramebufferColorView,
    .nativeId = framebufferColorNativeId,
};

fn framebufferColorView(_: *anyopaque, target: *const RhiFramebuffer) TextureView {
    return .{
        .impl = target.impl,
        .vtable = &texture_view_vtable,
    };
}

fn bindFramebufferColorView(impl: *const anyopaque, unit: u16) void {
    const framebuffer: *const OpenGLFramebuffer = @ptrCast(@alignCast(impl));
    framebuffer.bindColorTexture(unit);
}

fn framebufferColorNativeId(impl: *const anyopaque) u32 {
    const framebuffer: *const OpenGLFramebuffer = @ptrCast(@alignCast(impl));
    return framebuffer.colorTextureId();
}

fn createGraphicsPipeline(impl: *anyopaque, desc: RhiGraphicsPipeline.GraphicsPipelineDesc) anyerror!RhiGraphicsPipeline {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    const pipeline = try self.allocator.create(OpenGLGraphicsPipeline);
    errdefer self.allocator.destroy(pipeline);
    pipeline.* = try OpenGLGraphicsPipeline.init(self.allocator, desc);

    const sort_key = self.next_pipeline_sort_key;
    self.next_pipeline_sort_key +%= 1;
    if (self.next_pipeline_sort_key == 0) {
        self.next_pipeline_sort_key = 1;
    }

    return .{
        .impl = pipeline,
        .vtable = &OpenGLGraphicsPipeline.vtable,
        .sort_key = sort_key,
    };
}
