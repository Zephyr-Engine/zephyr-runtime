const std = @import("std");
const zcs = @import("zcs");
const zimp = @import("zimp");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const Framebuffer = @import("opengl/framebuffer.zig").Framebuffer;
const camera_system = @import("../scene/camera.zig");
const components = @import("../ecs/components.zig");
const Material = @import("material.zig").Material;
const debug_stats = @import("debug_stats.zig");
const math = @import("../core/math.zig");
const ecs = @import("../ecs/world.zig");
const Mesh = @import("mesh.zig").Mesh;
const c = @import("../c.zig");
const gl = c.glad;

const Renderer = @This();

pub const RenderViewport = struct {
    width: u32 = 1,
    height: u32 = 1,

    pub fn aspect(self: RenderViewport) f32 {
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(@max(1, self.height)));
    }
};

pub const RenderTarget = union(enum) {
    default_framebuffer: RenderViewport,
    framebuffer: *Framebuffer,

    fn bind(self: RenderTarget) RenderViewport {
        return switch (self) {
            .default_framebuffer => |viewport| blk: {
                Framebuffer.bindDefault(viewport.width, viewport.height);
                break :blk viewport;
            },
            .framebuffer => |framebuffer| blk: {
                framebuffer.bind();
                break :blk .{ .width = framebuffer.width, .height = framebuffer.height };
            },
        };
    }
};

pub const DrawItem = struct {
    mesh: *const Mesh,
    material: *const Material,
    model: math.Mat4,
    bounds_min: [3]f32,
    bounds_max: [3]f32,
    depth_key: f32 = 0,
};

pub const RenderQueues = struct {
    solid: std.ArrayList(DrawItem),
    alpha_test: std.ArrayList(DrawItem),
    transparent: std.ArrayList(DrawItem),

    fn clear(self: *RenderQueues) void {
        self.solid.clearRetainingCapacity();
        self.alpha_test.clearRetainingCapacity();
        self.transparent.clearRetainingCapacity();
    }
};

stats: debug_stats.Collector = .{},
render_queues: RenderQueues = .{
    .solid = .empty,
    .alpha_test = .empty,
    .transparent = .empty,
},
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Renderer {
    return .{
        .allocator = allocator,
    };
}

pub fn render(self: *Renderer, world: *zcs.World, assets: *AssetManager, target: RenderTarget) !void {
    const viewport = target.bind();
    self.stats.beginGpuTimer();
    defer self.stats.endGpuTimer();

    self.render_queues.clear();
    try self.renderWorld(world, assets, viewport);
}

fn renderWorld(self: *Renderer, world: *zcs.World, assets: *AssetManager, viewport: RenderViewport) !void {
    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glClearColor(0.4, 0.4, 0.4, 1);
    gl.glDepthMask(gl.GL_TRUE);
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

    const camera_entity = camera_system.active(world) orelse {
        std.log.warn("Skipping scene render: no active camera", .{});
        return;
    };

    try self.accumlateQueues(world, assets);
    try self.renderFromCamera(world, viewport, camera_entity);
}

pub fn setDebugStatsEnabled(self: *Renderer, enabled: bool) void {
    self.debug_stats.setEnabled(enabled);
}

pub fn debugStats(self: *const Renderer) ?debug_stats.DebugStats {
    return self.debug_stats.snapshot();
}

pub fn recordCpuFrame(self: *Renderer, delta_time: f32, elapsed_ms: f32) void {
    self.debug_stats.recordCpuFrame(delta_time, elapsed_ms);
}

pub fn deinit(self: *Renderer) void {
    self.debug_stats.deinit();
    self.render_queues.solid.deinit(self.allocator);
    self.render_queues.alpha_test.deinit(self.allocator);
    self.render_queues.transparent.deinit(self.allocator);

    self.* = undefined;
}

fn accumlateQueues(self: *Renderer, world: *zcs.World, assets: *AssetManager) !void {
    var iter = world.query(.{
        .read = &.{ components.TransformComponent, components.MeshRenderComponent },
    });

    while (iter.each()) |row| {
        const transform = row.read(components.TransformComponent);
        const target = row.read(components.MeshRenderComponent);

        const material = assets.get(Material, target.material) orelse {
            continue;
        };
        const mesh = assets.get(Mesh, target.mesh) orelse {
            continue;
        };

        const draw_item = DrawItem{
            .mesh = mesh,
            .material = material,
            .model = transform.modelMatrix(),
            .bounds_min = mesh.aabb_min,
            .bounds_max = mesh.aabb_max,
        };

        switch (material.source.render_state.alpha_mode) {
            .solid => try self.render_queues.solid.append(self.allocator, draw_item),
            .alpha_test => try self.render_queues.alpha_test.append(self.allocator, draw_item),
            .alpha_blend => try self.render_queues.transparent.append(self.allocator, draw_item),
        }
    }
}

fn renderFromCamera(self: *Renderer, world: *zcs.World, viewport: RenderViewport, camera_entity: ecs.EntityID) !void {
    const camera = world.getComponent(camera_entity, components.CameraComponent) orelse {
        return error.InvalidCamera;
    };

    const camera_transform = world.getComponent(camera_entity, components.TransformComponent) orelse {
        return error.InvalidCamera;
    };

    const view = camera.viewMatrix(camera_transform);
    const projection = camera.projectionMatrix(viewport.aspect());

    renderQueue(self.render_queues.solid, view, projection);
    renderQueue(self.render_queues.alpha_test, view, projection);
    renderQueue(self.render_queues.transparent, view, projection);
}

fn renderQueue(queue: std.ArrayList(DrawItem), view: math.Mat4, projection: math.Mat4) void {
    for (queue.items) |draw_item| {
        applyRenderState(draw_item.material.source.render_state);

        draw_item.material.bind();
        draw_item.material.setUniform("u_view", view);
        draw_item.material.setUniform("u_projection", projection);

        for (draw_item.mesh.parts) |*part| {
            draw_item.material.setUniform("u_model", part.transform.mul(draw_item.model));
            part.draw();
        }
    }
}

fn applyRenderState(state: zimp.RenderState) void {
    if (state.depth_test) {
        gl.glEnable(gl.GL_DEPTH_TEST);
    } else {
        gl.glDisable(gl.GL_DEPTH_TEST);
    }

    if (state.depth_write) {
        gl.glDepthMask(gl.GL_TRUE);
    } else {
        gl.glDepthMask(gl.GL_FALSE);
    }

    switch (state.cull_mode) {
        .none => {
            gl.glDisable(gl.GL_CULL_FACE);
        },
        .front => {
            gl.glEnable(gl.GL_CULL_FACE);
            gl.glCullFace(gl.GL_FRONT);
        },
        .back => {
            gl.glEnable(gl.GL_CULL_FACE);
            gl.glCullFace(gl.GL_BACK);
        },
    }

    switch (state.alpha_mode) {
        .solid => {
            gl.glDisable(gl.GL_BLEND);
            gl.glDepthMask(gl.GL_TRUE);
        },
        .alpha_test => {
            gl.glDisable(gl.GL_BLEND);
            gl.glDepthMask(gl.GL_TRUE);
        },
        .alpha_blend => {
            gl.glEnable(gl.GL_BLEND);
            gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
            gl.glDepthMask(gl.GL_FALSE);
        },
    }
}

test "render viewport aspect guards against zero height" {
    try std.testing.expectApproxEqAbs(@as(f32, 16.0 / 9.0), (Renderer.RenderViewport{ .width = 1920, .height = 1080 }).aspect(), 0.0001);
    try std.testing.expectEqual(@as(f32, 640.0), (Renderer.RenderViewport{ .width = 640, .height = 0 }).aspect());
}
