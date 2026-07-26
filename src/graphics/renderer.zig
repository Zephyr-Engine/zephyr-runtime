const std = @import("std");

const runtime_context = @import("../core/runtime_context.zig");
const camera_system = @import("../scene/camera.zig");
const components = @import("../ecs/components.zig");
const Material = @import("material.zig").Material;
const ecs = @import("../ecs/world.zig");
const Mesh = @import("mesh.zig").Mesh;
const c = @import("../c.zig");
const gl = c.glad;

pub fn Renderer(comptime Ecs: type) type {
    const RuntimeContext = runtime_context.RuntimeContext(Ecs);

    return struct {
        pub fn renderWorld(ctx: *RuntimeContext) !void {
            gl.glEnable(gl.GL_DEPTH_TEST);
            gl.glClearColor(0.4, 0.4, 0.4, 1);
            gl.glDepthMask(gl.GL_TRUE);
            gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

            const camera_entity = camera_system.active(&ctx.world) orelse {
                std.log.warn("Skipping scene render: no active camera", .{});
                return;
            };

            try renderFromCamera(ctx, camera_entity);
        }

        pub fn renderFromCamera(ctx: *RuntimeContext, camera_entity: ecs.EntityID) !void {
            const camera = ctx.world.getComponent(camera_entity, components.CameraComponent) orelse {
                return error.InvalidCamera;
            };
            const camera_transform = ctx.world.getComponent(camera_entity, components.TransformComponent) orelse {
                return error.InvalidCamera;
            };

            const view = camera.viewMatrix(camera_transform);
            const projection = camera.projectionMatrix(ctx.render_viewport.aspect());

            var iter = ctx.world.query(.{
                .read = &.{ components.TransformComponent, components.MeshRenderComponent },
            });
            while (iter.each()) |row| {
                const transform = row.read(components.TransformComponent);
                const target = row.read(components.MeshRenderComponent);

                const material = ctx.assets.get(Material, target.material) orelse {
                    continue;
                };
                const mesh = ctx.assets.get(Mesh, target.mesh) orelse {
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
}
