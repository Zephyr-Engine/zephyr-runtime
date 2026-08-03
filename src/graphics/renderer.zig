const zimp = @import("zimp");
const std = @import("std");
const zcs = @import("zcs");

const render_submission = @import("render_submission.zig");
const Collector = @import("opengl/stats_collector.zig");
const camera_system = @import("../scene/camera.zig");
const components = @import("../ecs/components.zig");
const render_state = @import("render_state.zig");
const DebugStats = @import("debug_stats.zig");
const Device = @import("rhi/device.zig");
const device_factory = @import("device_factory.zig");
const math = @import("../core/math.zig");
const ecs = @import("../ecs/world.zig");
const log = @import("../core/log.zig");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const Material = @import("material.zig");
const Mesh = @import("mesh.zig");

const DrawItem = render_submission.DrawItem;

const Renderer = @This();

pub const RenderViewport = Device.RenderViewport;
pub const RenderTarget = Device.RenderTarget;

device: Device,
submissions: std.ArrayList(DrawItem) = .empty,
stats: Collector = .{},
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, backend: device_factory.Backend) !Renderer {
    return .{
        .allocator = allocator,
        .device = try device_factory.init(allocator, backend),
    };
}

pub fn render(self: *Renderer, world: *zcs.World, assets: *AssetManager, target: RenderTarget) !void {
    const viewport = target.viewport();
    self.stats.beginGpuTimer();
    defer self.stats.endGpuTimer();

    self.submissions.clearRetainingCapacity();
    try self.renderWorld(world, assets, target, viewport);
}

fn renderWorld(self: *Renderer, world: *zcs.World, assets: *AssetManager, target: RenderTarget, viewport: RenderViewport) !void {
    try self.device.beginRenderPass(.{
        .target = target,
        .color = .{ .clear = .{ 0.4, 0.4, 0.4, 1 } },
        .depth = .{ .clear = 1 },
    });
    defer self.device.endRenderPass();

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
    self.device.deinit();

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

    self.renderQueue(view, projection);
}

fn renderQueue(self: *Renderer, view: math.Mat4, projection: math.Mat4) void {
    for (self.submissions.items) |draw_item| {
        self.device.bindGraphicsPipeline(draw_item.material.pipeline);

        draw_item.material.bindResources();
        self.device.setGraphicsPipelineUniformByName(draw_item.material.pipeline, "u_view", .{ .mat4 = view.fields });
        self.device.setGraphicsPipelineUniformByName(draw_item.material.pipeline, "u_projection", .{ .mat4 = projection.fields });
        self.device.setGraphicsPipelineUniformByName(draw_item.material.pipeline, "u_model", .{ .mat4 = draw_item.model.fields });

        draw_item.part.drawSubmesh(draw_item.submesh);
    }
}

test "render viewport aspect guards against zero height" {
    try std.testing.expectApproxEqAbs(@as(f32, 16.0 / 9.0), (Renderer.RenderViewport{ .width = 1920, .height = 1080 }).aspect(), 0.0001);
    try std.testing.expectEqual(@as(f32, 640.0), (Renderer.RenderViewport{ .width = 640, .height = 0 }).aspect());
}
