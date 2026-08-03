const zimp = @import("zimp");
const std = @import("std");
const zcs = @import("zcs");

const render_submission = @import("render_submission.zig");
const Collector = @import("opengl/stats_collector.zig");
const camera_system = @import("../scene/camera.zig");
const components = @import("../ecs/components.zig");
const render_state = @import("render_state.zig");
const DebugStats = @import("debug_stats.zig");
const math = @import("../core/math.zig");
const ecs = @import("../ecs/world.zig");
const log = @import("../core/log.zig");

const applyFixedState = @import("opengl/render_state.zig").apply;
const beginRenderPass = @import("opengl/render_state.zig").begin;
const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const Framebuffer = @import("opengl/framebuffer.zig");
const Material = @import("material.zig").Material;
const Mesh = @import("mesh.zig");

const DrawItem = render_submission.DrawItem;

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

submissions: std.ArrayList(DrawItem) = .empty,
stats: Collector = .{},
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

    self.submissions.clearRetainingCapacity();
    try self.renderWorld(world, assets, viewport);
}

fn renderWorld(self: *Renderer, world: *zcs.World, assets: *AssetManager, viewport: RenderViewport) !void {
    beginRenderPass(.{
        .color = .{ .clear = .{ 0.4, 0.4, 0.4, 1 } },
        .depth = .{ .clear = 1 },
    });

    const camera_entity = camera_system.active(world) orelse {
        std.log.warn("Skipping scene render: no active camera", .{});
        return;
    };

    try self.renderFromCamera(world, assets, viewport, camera_entity);
}

pub fn setDebugStatsEnabled(self: *Renderer, enabled: bool) void {
    self.stats.setEnabled(enabled);
}

pub fn debugStats(self: *const Renderer) ?DebugStats {
    return self.stats.snapshot();
}

pub fn recordCpuFrame(self: *Renderer, delta_time: f32, elapsed_ms: f32) void {
    self.stats.recordCpuFrame(delta_time, elapsed_ms);
}

pub fn deinit(self: *Renderer) void {
    self.stats.deinit();
    self.submissions.deinit(self.allocator);

    self.* = undefined;
}

fn gatherDrawItems(self: *Renderer, world: *zcs.World, assets: *AssetManager, camera: *const components.CameraComponent, view: math.Mat4) !void {
    var iter = world.query(.{
        .read = &.{ components.TransformComponent, components.MeshRenderComponent },
    });

    while (iter.each()) |row| {
        const transform = row.read(components.TransformComponent);
        const target = row.read(components.MeshRenderComponent);

        const model = transform.modelMatrix();
        const mesh = assets.get(Mesh, target.mesh) orelse {
            continue;
        };

        for (mesh.parts) |*part| {
            const final_model = part.transform.mul(model);

            for (part.submeshes) |*submesh| {
                const material_id = mesh.materialIdForSlot(submesh.material_index) orelse {
                    log.err("mesh submesh references invalid material slot {d}", .{submesh.material_index});
                    continue;
                };
                const material = assets.get(Material, material_id) orelse continue;

                const state = material.source.render_state;

                try self.submissions.append(self.allocator, .{
                    .part = part,
                    .submesh = submesh,
                    .material_id = material_id,
                    .material = material,
                    .model = final_model,
                    .depth_key = camera.calculateDepth(
                        final_model,
                        view,
                        part.bounds_min,
                        part.bounds_max,
                    ),
                    .phase = state.alpha_mode,
                    .pipeline_key = .generate(material),
                });
            }
        }
    }
}

fn renderFromCamera(self: *Renderer, world: *zcs.World, assets: *AssetManager, viewport: RenderViewport, camera_entity: ecs.EntityID) !void {
    const camera = world.getComponent(camera_entity, components.CameraComponent) orelse {
        return error.InvalidCamera;
    };

    const camera_transform = world.getComponent(camera_entity, components.TransformComponent) orelse {
        return error.InvalidCamera;
    };

    const view = camera.viewMatrix(camera_transform);
    const projection = camera.projectionMatrix(viewport.aspect());

    try self.gatherDrawItems(world, assets, camera, view);
    std.mem.sort(DrawItem, self.submissions.items, {}, DrawItem.lessThan);

    renderQueue(self.submissions, view, projection);
}

fn renderQueue(queue: std.ArrayList(DrawItem), view: math.Mat4, projection: math.Mat4) void {
    for (queue.items) |draw_item| {
        draw_item.material.shader.bind();
        applyFixedState(.generate(draw_item.material.source.render_state));

        draw_item.material.bindResources();
        draw_item.material.shader.setUniform("u_view", view);
        draw_item.material.shader.setUniform("u_projection", projection);
        draw_item.material.shader.setUniform("u_model", draw_item.model);

        draw_item.part.drawSubmesh(draw_item.submesh);
    }
}

test "render viewport aspect guards against zero height" {
    try std.testing.expectApproxEqAbs(@as(f32, 16.0 / 9.0), (Renderer.RenderViewport{ .width = 1920, .height = 1080 }).aspect(), 0.0001);
    try std.testing.expectEqual(@as(f32, 640.0), (Renderer.RenderViewport{ .width = 640, .height = 0 }).aspect());
}
