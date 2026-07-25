const scene = @import("zimp").scene;
const std = @import("std");

const SceneRuntimeInstance = @import("runtime_instance.zig").SceneRuntimeInstance;
const RuntimeContext = @import("../core/runtime_context.zig").RuntimeContext;
const SchemaRegistry = @import("schema_registry.zig").SchemaRegistry;
const Project = @import("../project/project.zig").Project;
const log = @import("../core/log.zig");

pub fn LoadedScene(comptime Ecs: type) type {
    return struct {
        instance: SceneRuntimeInstance(Ecs),
        document: scene.SceneDocument,

        pub fn init(allocator: std.mem.Allocator, document: scene.SceneDocument) !@This() {
            return .{
                .instance = .init(allocator, document.scene_id),
                .document = document,
            };
        }

        pub fn loadScene(ctx: *RuntimeContext(Ecs), path: []const u8) !@This() {
            const bytes = try ctx.project.root_dir.readFileAlloc(
                ctx.io,
                path,
                ctx.allocator,
                .limited(scene.json_codec.max_scene_bytes),
            );
            defer ctx.allocator.free(bytes);

            if (std.mem.startsWith(u8, bytes, scene.binary_codec.magic)) {
                return .init(ctx.allocator, try scene.binary_codec.decode(ctx.allocator, bytes));
            }

            return .init(ctx.allocator, try scene.json_codec.decode(ctx.allocator, bytes));
        }

        pub fn loadDefaultScene(ctx: *RuntimeContext(Ecs)) !@This() {
            const path = ctx.project.manifest.default_scene orelse return error.DefaultSceneNotFound;

            return loadScene(ctx, path);
        }

        pub fn start(self: *@This(), ctx: *RuntimeContext(Ecs)) !void {
            try self.instance.spawnEntities(&ctx.world, ctx.schemas, ctx.assets, &self.document);
        }

        pub fn deinit(self: *@This(), world: *Ecs.World) void {
            self.instance.deinit(world);
            self.document.deinit();
        }
    };
}
