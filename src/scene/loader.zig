const scene = @import("zimp").scene;
const std = @import("std");
const zcs = @import("zcs");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const SceneRuntimeInstance = @import("runtime_instance.zig").SceneRuntimeInstance;
const SchemaRegistry = @import("schema_registry.zig").SchemaRegistry;
const Project = @import("../project/project.zig").Project;
const log = @import("../core/log.zig");

pub const LoadedScene = struct {
    instance: SceneRuntimeInstance,
    document: scene.SceneDocument,

    pub fn init(allocator: std.mem.Allocator, document: scene.SceneDocument) !@This() {
        return .{
            .instance = .init(allocator, document.scene_id),
            .document = document,
        };
    }

    pub fn loadScene(allocator: std.mem.Allocator, io: std.Io, project: *const Project, path: []const u8) !@This() {
        const bytes = try project.root_dir.readFileAlloc(
            io,
            path,
            allocator,
            .limited(scene.json_codec.max_scene_bytes),
        );
        defer allocator.free(bytes);

        if (std.mem.startsWith(u8, bytes, scene.binary_codec.magic)) {
            return .init(allocator, try scene.binary_codec.decode(allocator, bytes));
        }

        return .init(allocator, try scene.json_codec.decode(allocator, bytes));
    }

    pub fn loadDefaultScene(allocator: std.mem.Allocator, io: std.Io, project: *const Project) !@This() {
        const path = project.manifest.default_scene orelse return error.DefaultSceneNotFound;

        return loadScene(allocator, io, project, path);
    }

    pub fn start(self: *@This(), world: *zcs.World, schemas: *const SchemaRegistry, assets: *AssetManager) !void {
        try self.instance.spawnEntities(world, schemas, assets, &self.document);
    }

    pub fn deinit(self: *@This(), world: *zcs.World) void {
        self.instance.deinit(world);
        self.document.deinit();
    }
};
