const zimp = @import("zimp");
const std = @import("std");
const zcs = @import("zcs");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const SceneRuntimeInstance = @import("runtime_instance.zig");
const SchemaRegistry = @import("schema_registry.zig");
const Project = @import("../project/project.zig");

const scene = zimp.scene;

const LoadedScene = @This();

registry: *const SchemaRegistry,
instance: SceneRuntimeInstance,
document: scene.SceneDocument,
assets: *AssetManager,
world: *zcs.World,

pub fn init(allocator: std.mem.Allocator, document: scene.SceneDocument, registry: *SchemaRegistry, assets: *AssetManager, world: *zcs.World) !LoadedScene {
    return .{
        .instance = .init(allocator, document.scene_id),
        .registry = registry,
        .document = document,
        .assets = assets,
        .world = world,
    };
}

pub fn start(self: *LoadedScene) !void {
    try self.instance.spawnEntities(
        self.world,
        self.registry,
        self.assets,
        &self.document,
    );
}

pub fn spawnEntity(self: *LoadedScene, entity: scene.SceneEntity) !zcs.EntityID {
    return self.instance.spawnEntity(
        self.world,
        self.registry,
        self.assets,
        entity,
    );
}

pub fn removeEntity(self: *LoadedScene, id: zimp.SceneEntityId) !void {
    return self.instance.despawnEntity(self.world, id);
}

pub fn setActiveCamera(self: *LoadedScene, id: zimp.SceneEntityId) !void {
    try self.instance.setActiveCamera(self.world, id);
}

pub fn addComponent(self: *LoadedScene, entity: *const scene.SceneEntity, component: scene.SceneComponent) !void {
    const entity_id = try self.instance.resolve(entity.id);
    return self.instance.addComponent(
        self.world,
        self.registry,
        self.assets,
        entity_id,
        component,
    );
}

pub fn removeComponent(self: *LoadedScene, entity: *const scene.SceneEntity, component: zimp.ComponentTypeId) !void {
    const entity_id = try self.instance.resolve(entity.id);
    return self.instance.removeComponent(
        self.world,
        self.registry,
        entity_id,
        component,
    );
}

pub fn setField(self: *LoadedScene, entity: *const scene.SceneEntity, component: zimp.ComponentTypeId, number: u32, value: zimp.scene.Value) !void {
    const entity_id = try self.instance.resolve(entity.id);
    return self.instance.setField(
        self.world,
        self.registry,
        entity_id,
        component,
        number,
        value,
    );
}

pub fn deinit(self: *LoadedScene) void {
    self.instance.deinit(self.world);
    self.document.deinit();
}

pub fn reset(self: *LoadedScene) !void {
    self.instance.reset(self.world);
    try self.instance.spawnEntities(
        self.world,
        self.registry,
        self.assets,
        &self.document,
    );
}

test "loadDefaultScene rejects projects without a configured default scene" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var project = Project{
        .manifest = .{ .project_id = .zero },
        .root_dir = try std.Io.Dir.openDir(tmp.dir, std.testing.io, ".", .{}),
    };
    defer project.root_dir.close(std.testing.io);

    try std.testing.expectError(
        error.DefaultSceneNotFound,
        project.loadDefaultScene(std.testing.allocator, std.testing.io),
    );
}
