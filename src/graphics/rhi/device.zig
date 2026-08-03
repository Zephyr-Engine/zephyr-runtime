const GraphicsPipeline = @import("graphics_pipeline.zig");
const render_state = @import("../render_state.zig");
const TextureView = @import("texture_view.zig");
const Framebuffer = @import("framebuffer.zig");

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

    // renderer
    bindRenderTarget: *const fn (impl: *anyopaque, target: RenderTarget) void,
    beginRenderPass: *const fn (impl: *anyopaque, info: RenderPassInfo) anyerror!void,
    endRenderPass: *const fn (impl: *anyopaque) void,

    // framebuffers
    createFramebuffer: *const fn (impl: *anyopaque, desc: Framebuffer.FramebufferDesc) anyerror!Framebuffer,
    destroyFramebuffer: *const fn (impl: *anyopaque, target: *Framebuffer) void,
    resizeFramebuffer: *const fn (impl: *anyopaque, target: *Framebuffer, extent: Framebuffer.Extent2D) anyerror!void,
    framebufferColorView: *const fn (impl: *anyopaque, target: *const Framebuffer) TextureView,
    bindTextureView: *const fn (impl: *anyopaque, view: TextureView, unit: u16) void,
    textureViewNativeId: *const fn (impl: *anyopaque, view: TextureView) u32,

    // graphics pipelines
    createGraphicsPipeline: *const fn (impl: *anyopaque, desc: GraphicsPipeline.GraphicsPipelineDesc) anyerror!GraphicsPipeline,
    destroyGraphicsPipeline: *const fn (impl: *anyopaque, pipeline: *GraphicsPipeline) void,
    bindGraphicsPipeline: *const fn (impl: *anyopaque, pipeline: GraphicsPipeline) void,
    graphicsPipelineUniformLocation: *const fn (impl: *anyopaque, pipeline: GraphicsPipeline, name: []const u8) ?GraphicsPipeline.UniformLocation,
    setGraphicsPipelineUniform: *const fn (impl: *anyopaque, pipeline: GraphicsPipeline, location: GraphicsPipeline.UniformLocation, value: GraphicsPipeline.UniformValue) void,
};

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

pub fn bindRenderTarget(self: *Device, target: RenderTarget) void {
    self.vtable.bindRenderTarget(self.impl, target);
}

pub fn endRenderPass(self: *Device) void {
    self.vtable.endRenderPass(self.impl);
}

pub fn framebufferColorView(self: *Device, target: *const Framebuffer) TextureView {
    return self.vtable.framebufferColorView(self.impl, target);
}

pub fn bindTextureView(self: *Device, view: TextureView, unit: u16) void {
    self.vtable.bindTextureView(self.impl, view, unit);
}

pub fn textureViewNativeId(self: *Device, view: TextureView) u32 {
    return self.vtable.textureViewNativeId(self.impl, view);
}

pub fn createGraphicsPipeline(self: *Device, desc: GraphicsPipeline.GraphicsPipelineDesc) anyerror!GraphicsPipeline {
    return self.vtable.createGraphicsPipeline(self.impl, desc);
}

pub fn destroyGraphicsPipeline(self: *Device, pipeline: *GraphicsPipeline) void {
    self.vtable.destroyGraphicsPipeline(self.impl, pipeline);
}

pub fn bindGraphicsPipeline(self: *Device, pipeline: GraphicsPipeline) void {
    self.vtable.bindGraphicsPipeline(self.impl, pipeline);
}

pub fn graphicsPipelineUniformLocation(self: *Device, pipeline: GraphicsPipeline, name: []const u8) ?GraphicsPipeline.UniformLocation {
    return self.vtable.graphicsPipelineUniformLocation(self.impl, pipeline, name);
}

pub fn setGraphicsPipelineUniform(self: *Device, pipeline: GraphicsPipeline, location: GraphicsPipeline.UniformLocation, value: GraphicsPipeline.UniformValue) void {
    self.vtable.setGraphicsPipelineUniform(self.impl, pipeline, location, value);
}

pub fn setGraphicsPipelineUniformByName(self: *Device, pipeline: GraphicsPipeline, name: []const u8, value: GraphicsPipeline.UniformValue) void {
    const location = self.graphicsPipelineUniformLocation(pipeline, name) orelse return;
    self.setGraphicsPipelineUniform(pipeline, location, value);
}
