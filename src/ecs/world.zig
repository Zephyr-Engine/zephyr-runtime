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
schemas: *SchemaRegistry,
command_buffer: zcs.CommandBuffer,
active_scene: ?LoadedScene = null,

pub fn init(self: *WorldInstance, allocator: std.mem.Allocator, schemas: *SchemaRegistry, comptime game: Game) !void {
    var world = zcs.World.init(allocator);
    errdefer world.deinit();

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

    self.* = .{
        .world = world,
        .schemas = schemas,
        .command_buffer = undefined,
    };
    self.command_buffer = zcs.CommandBuffer.init(&self.world);
}

pub fn deinit(self: *WorldInstance) void {
    if (self.active_scene) |*scene| {
        scene.deinit(&self.world);
        self.active_scene = null;
    }
    self.command_buffer.deinit();
    self.world.deinit();
}

pub fn startScene(
    self: *WorldInstance,
    allocator: std.mem.Allocator,
    assets: *AssetManager,
    document: zimp.scene.SceneDocument,
) !void {
    if (self.active_scene) |*scene| {
        if (!scene.document.scene_id.eql(document.scene_id)) {
            scene.deinit(&self.world);
            self.active_scene = null;
        } else {
            return;
        }
    }

    var scene = try LoadedScene.init(allocator, document);
    try scene.start(&self.world, self.schemas, assets);

    self.active_scene = scene;
}

pub fn resetActiveScene(self: *WorldInstance, assets: *AssetManager) !void {
    if (self.active_scene) |*scene| {
        try scene.reset(&self.world, self.schemas, assets);
    }
}

pub fn setResource(self: *WorldInstance, comptime Resource: type, value: Resource) !void {
    try self.world.setResource(Resource, value);
}

pub fn getResource(self: *WorldInstance, comptime Resource: type) *Resource {
    return self.world.getResource(Resource);
}

pub fn registerEngineComponents(world: *zcs.World) !void {
    _ = try registerComponent(world, components.TransformComponent, "zephyr.transform");
    _ = try registerComponent(world, components.MeshRenderComponent, "zephyr.meshrender");
    _ = try registerComponent(world, components.CameraComponent, "zephyr.camera");
}

fn registerComponent(world: *zcs.World, comptime T: type, name: []const u8) !zcs.ComponentId {
    const codec = comptime deriveCodec(T);
    const schema_hash = zimp.scene.descriptor.schemaHash(&.{codec.schema});
    return world.registerType(T, .{ .name = name, .schema_hash = schema_hash });
}

const testing = std.testing;

const TestGameComponent = struct {
    charge: i32 = 0,

    pub const schema_meta = zimp.scene.SchemaMeta{
        .id = "12341234-1234-4234-8234-123412341234",
        .name = "test.game.component",
        .display_name = "Test Game Component",
        .version = 1,
        .fields = &.{.{ .name = "charge", .number = 1 }},
    };
};

const empty_game: Game = .{ .components = &.{}, .update_schedule = .{} };
const game_with_component: Game = .{ .components = &.{TestGameComponent}, .update_schedule = .{} };

test "init registers engine components and schemas" {
    var schemas = SchemaRegistry.init(testing.allocator);
    defer schemas.deinit();

    var instance: WorldInstance = undefined;
    try instance.init(testing.allocator, &schemas, empty_game);
    defer instance.deinit();

    try testing.expect(schemas.getByName("zephyr.runtime.transform") != null);
    try testing.expect(schemas.getByName("zephyr.runtime.mesh.render") != null);
    try testing.expect(schemas.getByName("zephyr.runtime.camera") != null);
    try testing.expect(instance.active_scene == null);
}

test "init also registers game-specific components" {
    var schemas = SchemaRegistry.init(testing.allocator);
    defer schemas.deinit();

    var instance: WorldInstance = undefined;
    try instance.init(testing.allocator, &schemas, game_with_component);
    defer instance.deinit();

    const codec = schemas.getByName("test.game.component").?;
    try testing.expectEqual(@as(usize, 1), codec.schema.fields.len);
}

test "setResource and getResource round-trip a value" {
    var schemas = SchemaRegistry.init(testing.allocator);
    defer schemas.deinit();

    var instance: WorldInstance = undefined;
    try instance.init(testing.allocator, &schemas, empty_game);
    defer instance.deinit();

    const Score = struct { value: i32 };
    try instance.setResource(Score, .{ .value = 42 });
    try testing.expectEqual(@as(i32, 42), instance.getResource(Score).value);

    instance.getResource(Score).value = 7;
    try testing.expectEqual(@as(i32, 7), instance.getResource(Score).value);
}

test "resetActiveScene is a no-op without an active scene" {
    var schemas = SchemaRegistry.init(testing.allocator);
    defer schemas.deinit();

    var instance: WorldInstance = undefined;
    try instance.init(testing.allocator, &schemas, empty_game);
    defer instance.deinit();

    var assets: AssetManager = undefined;
    try instance.resetActiveScene(&assets);
}
