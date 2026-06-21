const std = @import("std");

const RuntimeContext = @import("../core/runtime_context.zig").RuntimeContext;
const Material = @import("material.zig").Material;
const components = @import("../ecs/components.zig");
const ecs = @import("../ecs/world.zig");
const camera_system = @import("../scene/camera.zig");
const Mesh = @import("mesh.zig").Mesh;
const c = @import("../c.zig");
const gl = c.glad;

pub fn renderWorld(ctx: *RuntimeContext) !void {
    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glClearColor(0.4, 0.4, 0.4, 1);
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

    const camera_entity = camera_system.active(&ctx.world) orelse {
        std.log.warn("Skipping scene render: no active camera", .{});
        return;
    };

    try renderFromCamera(ctx, camera_entity);
}

/// Renders the current view from any camera entity. The caller owns target
/// binding, so multiple cameras can render to independent framebuffers.
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
            // Asset loading is asynchronous. A target may exist before its
            // material is finalized; try it again on a later frame.
            continue;
        };
        const mesh = ctx.assets.get(Mesh, target.mesh) orelse {
            continue;
        };

        material.bind();
        material.setUniform("u_view", view);
        material.setUniform("u_projection", projection);
        material.setUniform("u_model", transform.modelMatrix());
        mesh.draw();
    }
}
