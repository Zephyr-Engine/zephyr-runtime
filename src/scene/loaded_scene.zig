const scene = @import("zimp").scene;
const std = @import("std");
const zcs = @import("zcs");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const SceneRuntimeInstance = @import("runtime_instance.zig");
const SchemaRegistry = @import("schema_registry.zig");
const Project = @import("../project/project.zig");

const LoadedScene = @This();

instance: SceneRuntimeInstance,
document: scene.SceneDocument,

pub fn init(allocator: std.mem.Allocator, document: scene.SceneDocument) !@This() {
    return .{
        .instance = .init(allocator, document.scene_id),
        .document = document,
    };
}

pub fn start(self: *@This(), world: *zcs.World, schemas: *const SchemaRegistry, assets: *AssetManager) !void {
    try self.instance.spawnEntities(world, schemas, assets, &self.document);
}

pub fn deinit(self: *@This(), world: *zcs.World) void {
    self.instance.deinit(world);
    self.document.deinit();
}

pub fn reset(self: *@This(), world: *zcs.World, schemas: *const SchemaRegistry, assets: *AssetManager) void {
    self.instance.reset(world);
    try self.instance.spawnEntities(world, schemas, assets, &self.document);
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
        LoadedScene.loadDefaultScene(std.testing.allocator, std.testing.io, &project),
    );
}
