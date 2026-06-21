const zcs = @import("zcs");

const components = @import("components.zig");

pub const Ecs = zcs.Registry(&.{
    components.TransformComponent,
    components.MeshRenderComponent,
    components.CameraComponent,
    components.FlyCameraController,
});

pub const World = Ecs.World;
pub const EntityID = zcs.EntityID;
