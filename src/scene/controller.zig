const std = @import("std");
const zcs = @import("zcs");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const SchemaRegistry = @import("schema_registry.zig");
const Project = @import("../project/project.zig");
const LoadedScene = @import("loader.zig");

const SceneController = @This();

active: ?LoadedScene = null,

pub fn startDefault(
    self: *SceneController,
    allocator: std.mem.Allocator,
    io: std.Io,
    project: *const Project,
    world: *zcs.World,
    schemas: *const SchemaRegistry,
    assets: *AssetManager,
) !void {
    if (self.active != null) {
        return error.SceneAlreadyStarted;
    }

    var scene = try LoadedScene.loadDefaultScene(allocator, io, project);
    errdefer scene.deinit(world);
    try scene.start(world, schemas, assets);
    self.active = scene;
}

pub fn deinit(self: *SceneController, world: *zcs.World) void {
    if (self.active) |*scene| {
        scene.deinit(world);
    }
    self.active = null;
}
