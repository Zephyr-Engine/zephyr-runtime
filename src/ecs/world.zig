const components = @import("components.zig");
const zcs = @import("zcs");

pub const EngineEcs = zcs.Registry(&.{
    components.TransformComponent,
    components.MeshRenderComponent,
    components.CameraComponent,
});

pub const EntityID = zcs.EntityID;

pub fn GameEcs(comptime game_components: []const type) type {
    comptime {
        const engine_components = .{
            components.TransformComponent,
            components.MeshRenderComponent,
            components.CameraComponent,
        };
        for (game_components, 0..) |T, i| {
            for (engine_components) |EngineComponent| {
                if (T == EngineComponent) {
                    @compileError("GameEcs components must not repeat runtime component " ++ @typeName(T));
                }
            }
            for (game_components[0..i]) |Other| {
                if (T == Other) {
                    @compileError("GameEcs component declared more than once: " ++ @typeName(T));
                }
            }
        }
    }

    const all_components = comptime blk: {
        var types: [3 + game_components.len]type = undefined;
        types[0] = components.TransformComponent;
        types[1] = components.MeshRenderComponent;
        types[2] = components.CameraComponent;
        for (game_components, 0..) |T, i| types[i + 3] = T;
        break :blk types;
    };
    return zcs.Registry(&all_components);
}
