const deriveCodec = @import("../scene/derive_schema.zig").deriveCodec;
const components = @import("components.zig");
const zimp = @import("zimp");
const zcs = @import("zcs");

pub const EntityID = zcs.EntityID;

pub fn registerEngineComponents(world: *zcs.World) !void {
    _ = try registerComponent(world, components.TransformComponent, "zephyr.Transform");
    _ = try registerComponent(world, components.MeshRenderComponent, "zephyr.MeshRender");
    _ = try registerComponent(world, components.CameraComponent, "zephyr.Camera");
}

pub fn registerComponent(world: *zcs.World, comptime T: type, name: []const u8) !zcs.ComponentId {
    const codec = comptime deriveCodec(T);
    const schema_hash = zimp.scene.descriptor.schemaHash(&.{codec.schema});
    return world.registerType(T, .{ .name = name, .schema_hash = schema_hash });
}
