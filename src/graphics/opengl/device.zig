const std = @import("std");

const rhi_device = @import("../rhi/device.zig");
const RhiFramebuffer = @import("../rhi/framebuffer.zig");
const RhiGraphicsPipeline = @import("../rhi/graphics_pipeline.zig");
const TextureView = @import("../rhi/texture_view.zig");
const ResourcePool = @import("../rhi/resource_pool.zig").ResourcePool;
const ResourceHandle = @import("../rhi/resource_handle.zig");
const render_state = @import("render_state.zig");
const OpenGLFramebuffer = @import("framebuffer.zig");
const OpenGLGraphicsPipeline = @import("graphics_pipeline.zig");

const OpenGLDevice = @This();

allocator: std.mem.Allocator,
framebuffers: ResourcePool(OpenGLFramebuffer) = .{},
pipelines: ResourcePool(OpenGLGraphicsPipeline) = .{},
next_pipeline_sort_key: u64 = 1,

const vtable = rhi_device.VTable{
    .deinit = deinit,
    .beginRenderPass = beginRenderPass,
    .endRenderPass = endRenderPass,

    // framebuffer
    .bindRenderTarget = bindRenderTarget,
    .createFramebuffer = createFramebuffer,
    .destroyFramebuffer = destroyFramebuffer,
    .resizeFramebuffer = resizeFramebuffer,
    .framebufferColorView = framebufferColorView,
    .bindTextureView = bindTextureView,
    .textureViewNativeId = textureViewNativeId,

    // graphics pipeline
    .createGraphicsPipeline = createGraphicsPipeline,
    .destroyGraphicsPipeline = destroyGraphicsPipeline,
    .bindGraphicsPipeline = bindGraphicsPipeline,
    .graphicsPipelineUniformLocation = graphicsPipelineUniformLocation,
    .setGraphicsPipelineUniform = setGraphicsPipelineUniform,
};

pub fn init(allocator: std.mem.Allocator) !rhi_device {
    const self = try allocator.create(OpenGLDevice);
    self.* = .{ .allocator = allocator };

    return .{ .impl = self, .vtable = &vtable };
}

fn deinit(impl: *anyopaque) void {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    for (self.framebuffers.slots.items) |*slot| {
        if (slot.resource) |*resource| {
            resource.deinit();
        }
    }

    for (self.pipelines.slots.items) |*slot| {
        if (slot.resource) |*pipeline| {
            pipeline.deinit();
        }
    }
    self.framebuffers.deinit(self.allocator);
    self.pipelines.deinit(self.allocator);
    const allocator = self.allocator;
    allocator.destroy(self);
}

fn createFramebuffer(impl: *anyopaque, desc: RhiFramebuffer.FramebufferDesc) anyerror!RhiFramebuffer {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    const extent = desc.extent.normalized();
    var resource = try OpenGLFramebuffer.init(.{
        .extent = extent,
        .color_format = desc.color_format,
        .depth_stencil_format = desc.depth_stencil_format,
    });
    errdefer resource.deinit();

    const allocation = try self.framebuffers.insert(self.allocator, resource);
    return .{
        .handle = .{
            .owner = self,
            .index = allocation.index,
            .generation = allocation.generation,
        },
        .extent = extent,
        .color_format = desc.color_format,
        .depth_stencil_format = desc.depth_stencil_format,
    };
}

fn destroyFramebuffer(impl: *anyopaque, target: *RhiFramebuffer) void {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    self.assertOwner(target.handle);
    var resource = self.framebuffers.remove(
        target.handle.index,
        target.handle.generation,
    ) orelse unreachable;

    resource.deinit();
    target.* = undefined;
}

fn resizeFramebuffer(impl: *anyopaque, target: *RhiFramebuffer, extent: RhiFramebuffer.Extent2D) anyerror!void {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    const normalized = extent.normalized();
    try self.resolveFramebuffer(target.*).resize(normalized.width, normalized.height);
    target.extent = normalized;
}

fn beginRenderPass(impl: *anyopaque, info: rhi_device.RenderPassInfo) anyerror!void {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    self.bindTarget(info.target);
    render_state.begin(.{ .color = info.color, .depth = info.depth });
}

fn bindRenderTarget(impl: *anyopaque, target: rhi_device.RenderTarget) void {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    self.bindTarget(target);
}

fn bindTarget(self: *OpenGLDevice, target: rhi_device.RenderTarget) void {
    switch (target) {
        .swapchain => |viewport| OpenGLFramebuffer.bindDefault(viewport.width, viewport.height),
        .framebuffer => |framebuffer_target| self.resolveFramebuffer(framebuffer_target.*).bind(),
    }
}

fn endRenderPass(_: *anyopaque) void {}

fn framebufferColorView(_: *anyopaque, target: *const RhiFramebuffer) TextureView {
    return TextureView.fromFramebuffer(target.*);
}

fn bindTextureView(impl: *anyopaque, view: TextureView, unit: u16) void {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    self.resolveFramebufferView(view).bindColorTexture(unit);
}

fn textureViewNativeId(impl: *anyopaque, view: TextureView) u32 {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    return self.resolveFramebufferView(view).colorTextureId();
}

fn createGraphicsPipeline(impl: *anyopaque, desc: RhiGraphicsPipeline.GraphicsPipelineDesc) anyerror!RhiGraphicsPipeline {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    var resource = try OpenGLGraphicsPipeline.init(self.allocator, desc);
    errdefer resource.deinit();

    const allocation = try self.pipelines.insert(self.allocator, resource);
    const sort_key = self.next_pipeline_sort_key;
    self.next_pipeline_sort_key = nextSortKey(sort_key);
    return .{
        .handle = .{
            .owner = self,
            .index = allocation.index,
            .generation = allocation.generation,
        },
        .sort_key = sort_key,
    };
}

fn destroyGraphicsPipeline(impl: *anyopaque, pipeline: *RhiGraphicsPipeline) void {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    self.assertOwner(pipeline.handle);
    var resource = self.pipelines.remove(pipeline.handle.index, pipeline.handle.generation) orelse unreachable;
    resource.deinit();
    pipeline.* = undefined;
}

fn bindGraphicsPipeline(impl: *anyopaque, pipeline: RhiGraphicsPipeline) void {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    self.resolvePipeline(pipeline).bind();
}

fn graphicsPipelineUniformLocation(impl: *anyopaque, pipeline: RhiGraphicsPipeline, name: []const u8) ?RhiGraphicsPipeline.UniformLocation {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    return self.resolvePipeline(pipeline).uniformLocation(name);
}

fn setGraphicsPipelineUniform(impl: *anyopaque, pipeline: RhiGraphicsPipeline, location: RhiGraphicsPipeline.UniformLocation, value: RhiGraphicsPipeline.UniformValue) void {
    const self: *OpenGLDevice = @ptrCast(@alignCast(impl));
    self.resolvePipeline(pipeline).setUniformFromLocation(location, value);
}

fn resolveFramebuffer(self: *OpenGLDevice, handle: RhiFramebuffer) *OpenGLFramebuffer {
    self.assertOwner(handle.handle);
    return self.framebuffers.get(handle.handle.index, handle.handle.generation) orelse unreachable;
}

fn resolveFramebufferView(self: *OpenGLDevice, view: TextureView) *OpenGLFramebuffer {
    return self.resolveFramebuffer(.{
        .handle = view.handle,
        .extent = undefined,
        .color_format = undefined,
        .depth_stencil_format = undefined,
    });
}

fn resolvePipeline(self: *OpenGLDevice, handle: RhiGraphicsPipeline) *OpenGLGraphicsPipeline {
    self.assertOwner(handle.handle);
    return self.pipelines.get(handle.handle.index, handle.handle.generation) orelse unreachable;
}

fn assertOwner(self: *OpenGLDevice, handle: ResourceHandle) void {
    std.debug.assert(handle.belongsTo(@as(*const anyopaque, @ptrCast(self))));
}

fn nextSortKey(current: u64) u64 {
    const next = current +% 1;
    return if (next == 0) 1 else next;
}

test "pipeline sort keys never use zero" {
    try std.testing.expectEqual(@as(u64, 1), nextSortKey(std.math.maxInt(u64)));
}
