const LoadedScene = @import("loader.zig").LoadedScene;
const RuntimeContext = @import("../core/runtime_context.zig").RuntimeContext;
const zcs = @import("zcs");

/// Owns the scene currently instantiated into the runtime world.
///
/// Keeping this boundary separate from the platform loop makes scene replacement
/// a local future extension rather than an Application concern.
pub const SceneController = struct {
    active: ?LoadedScene = null,

    pub fn startDefault(self: *SceneController, ctx: *RuntimeContext) !void {
        if (self.active != null) return error.SceneAlreadyStarted;

        var scene = try LoadedScene.loadDefaultScene(ctx);
        errdefer scene.deinit(&ctx.world);
        try scene.start(ctx);
        self.active = scene;
    }

    pub fn deinit(self: *SceneController, world: *zcs.World) void {
        if (self.active) |*scene| {
            scene.deinit(world);
        }
        self.active = null;
    }
};
