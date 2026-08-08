const zimp = @import("zimp");
const zcs = @import("zcs");
const std = @import("std");

const deriveCodec = @import("../scene/derive_schema.zig").deriveCodec;
const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const SceneRuntimeInstance = @import("../scene/runtime_instance.zig");
const SchemaRegistry = @import("../scene/schema_registry.zig");
const LoadedScene = @import("../scene/loaded_scene.zig");
const components = @import("components.zig");
const Game = @import("../core/game.zig");

pub const EntityID = zcs.EntityID;

const WorldInstance = @This();

world: zcs.World,
command_buffer: zcs.CommandBuffer,
active_scene: ?LoadedScene = null,

pub fn init(allocator: std.mem.Allocator, schemas: *SchemaRegistry, comptime game: Game) !WorldInstance {
    var world = zcs.World.init(allocator);

    try registerEngineComponents(&world);
    inline for (game.components) |Component| {
        const name = if (@hasDecl(Component, "schema_meta")) Component.schema_meta.name else @typeName(Component);
        _ = try registerComponent(&world, Component, name);
    }

    try schemas.registerComponents(&.{
        components.TransformComponent,
        components.MeshRenderComponent,
        components.CameraComponent,
    });
    try schemas.registerComponents(game.components);

    return .{
        .world = world,
        .command_buffer = zcs.CommandBuffer.init(&world),
    };
}

pub fn deinit(self: *WorldInstance) void {
    if (self.active_scene) |*scene| {
        scene.deinit(&self.world);
        self.active_scene = null;
    }
    self.world.deinit();
    self.command_buffer.deinit();
}

pub fn startScene(
    self: *WorldInstance,
    allocator: std.mem.Allocator,
    schemas: *const SchemaRegistry,
    assets: *AssetManager,
    document: *const zimp.scene.SceneDocument,
) !void {
    if (self.active_scene) |scene| {
        if (scene.scene_id != document.scene_id) {
            scene.deinit(&self.world);
        } else {
            scene.start(&self.world, schemas, assets, document);
            return;
        }
    }

    const scene = try LoadedScene.init(allocator, document);
    scene.start(&self.world, schemas, assets, document);

    self.active_scene = scene;
}

pub fn resetActiveScene(self: *WorldInstance, schemas: *const SchemaRegistry, assets: *AssetManager) !void {
    if (self.scene) |*scene| {
        scene.reset(&self.world, schemas, assets);
    }
}

pub fn setResource(self: *WorldInstance, comptime Resource: type, value: Resource) !void {
    try self.world.setResource(Resource, value);
}

pub fn getResource(self: *const WorldInstance, comptime Resource: type) ?*const Resource {
    return self.world.getResource(Resource);
}

fn registerEngineComponents(world: *zcs.World) !void {
    _ = try registerComponent(world, components.TransformComponent, "zephyr.transform");
    _ = try registerComponent(world, components.MeshRenderComponent, "zephyr.meshrender");
    _ = try registerComponent(world, components.CameraComponent, "zephyr.camera");
}

fn registerComponent(world: *zcs.World, comptime T: type, name: []const u8) !zcs.ComponentId {
    const codec = comptime deriveCodec(T);
    const schema_hash = zimp.scene.descriptor.schemaHash(&.{codec.schema});
    return world.registerType(T, .{ .name = name, .schema_hash = schema_hash });
}
