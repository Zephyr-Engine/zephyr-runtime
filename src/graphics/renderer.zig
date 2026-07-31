const std = @import("std");
const zcs = @import("zcs");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const Framebuffer = @import("opengl/framebuffer.zig").Framebuffer;
const camera_system = @import("../scene/camera.zig");
const components = @import("../ecs/components.zig");
const Material = @import("material.zig").Material;
const debug_stats = @import("debug_stats.zig");
const ecs = @import("../ecs/world.zig");
const Mesh = @import("mesh.zig").Mesh;
const c = @import("../c.zig");
const gl = c.glad;

pub const Renderer = struct {
    pub const DebugStats = debug_stats.DebugStats;

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

    debug_stats: debug_stats.Collector = .{},

    pub fn init(_: std.mem.Allocator) !Renderer {
        return .{};
    }

    pub fn render(self: *Renderer, world: *zcs.World, assets: *AssetManager, target: RenderTarget) !void {
        const viewport = target.bind();
        self.debug_stats.beginGpuTimer();
        defer self.debug_stats.endGpuTimer();
        try self.renderWorld(world, assets, viewport);
    }

    fn renderWorld(_: *Renderer, world: *zcs.World, assets: *AssetManager, viewport: RenderViewport) !void {
        gl.glEnable(gl.GL_DEPTH_TEST);
        gl.glClearColor(0.4, 0.4, 0.4, 1);
        gl.glDepthMask(gl.GL_TRUE);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

        const camera_entity = camera_system.active(world) orelse {
            std.log.warn("Skipping scene render: no active camera", .{});
            return;
        };

        try renderFromCamera(world, assets, viewport, camera_entity);
    }

    pub fn setDebugStatsEnabled(self: *Renderer, enabled: bool) void {
        self.debug_stats.setEnabled(enabled);
    }

    pub fn debugStats(self: *const Renderer) ?DebugStats {
        return self.debug_stats.snapshot();
    }

    pub fn recordCpuFrame(self: *Renderer, delta_time: f32, elapsed_ms: f32) void {
        self.debug_stats.recordCpuFrame(delta_time, elapsed_ms);
    }

    pub fn deinit(self: *Renderer) void {
        self.debug_stats.deinit();
        self.* = undefined;
    }

    fn renderFromCamera(world: *zcs.World, assets: *AssetManager, viewport: RenderViewport, camera_entity: ecs.EntityID) !void {
        const camera = world.getComponent(camera_entity, components.CameraComponent) orelse {
            return error.InvalidCamera;
        };

        const camera_transform = world.getComponent(camera_entity, components.TransformComponent) orelse {
            return error.InvalidCamera;
        };

        const view = camera.viewMatrix(camera_transform);
        const projection = camera.projectionMatrix(viewport.aspect());

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

            material.bind();
            material.setUniform("u_view", view);
            material.setUniform("u_projection", projection);
            const entity_transform = transform.modelMatrix();
            for (mesh.parts) |*part| {
                material.setUniform("u_model", part.transform.mul(entity_transform));
                part.draw();
            }
        }
    }
};

test "render viewport aspect guards against zero height" {
    try std.testing.expectApproxEqAbs(@as(f32, 16.0 / 9.0), (Renderer.RenderViewport{ .width = 1920, .height = 1080 }).aspect(), 0.0001);
    try std.testing.expectEqual(@as(f32, 640.0), (Renderer.RenderViewport{ .width = 640, .height = 0 }).aspect());
}
