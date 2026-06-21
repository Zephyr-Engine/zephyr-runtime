const std = @import("std");
const Scene = @import("scene.zig").Scene;
const ZEvent = @import("../core/event.zig").ZEvent;
const RuntimeContext = @import("../core/runtime_context.zig").RuntimeContext;
const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const log = @import("../core/log.zig");

pub const SceneManagerError = error{
    OutOfMemory,
    NoActiveScene,
};

pub const SceneManager = struct {
    scenes: std.ArrayList(Scene),
    allocator: std.mem.Allocator,
    active_scene_index: usize,

    pub fn init(allocator: std.mem.Allocator) SceneManagerError!*SceneManager {
        const manager = allocator.create(SceneManager) catch |err| {
            log.err("failed to allocate scene manager: {}", .{err});
            return SceneManagerError.OutOfMemory;
        };

        manager.* = SceneManager{
            .allocator = allocator,
            .scenes = .empty,
            .active_scene_index = 0,
        };

        return manager;
    }

    pub fn deinit(self: *SceneManager, ctx: *RuntimeContext) !void {
        var first_error: ?anyerror = null;
        for (self.scenes.items) |*scene| {
            scene.onCleanup(ctx) catch |err| {
                log.err("scene cleanup failed: {}", .{err});
                if (first_error == null) first_error = err;
            };
        }
        self.scenes.deinit(self.allocator);
        self.allocator.destroy(self);
        if (first_error) |err| return err;
    }

    pub inline fn getActiveScene(self: *const SceneManager) ?*Scene {
        if (self.scenes.items.len == 0) return null;
        return &self.scenes.items[self.active_scene_index];
    }

    pub fn addScene(self: *SceneManager, comptime scene: type, is_active: bool) SceneManagerError!void {
        try self.scenes.ensureUnusedCapacity(self.allocator, 1);
        const s = try Scene.init(scene, self.allocator, is_active);
        self.scenes.appendAssumeCapacity(s);

        if (s.is_active) {
            self.active_scene_index = self.scenes.items.len - 1;
        }
    }

    pub fn updateScene(self: *SceneManager, ctx: *RuntimeContext, delta_time: f32) !void {
        const active_scene = self.getActiveScene() orelse return SceneManagerError.NoActiveScene;
        try active_scene.onUpdate(ctx, delta_time);
    }

    pub fn handleEvent(self: *SceneManager, ctx: *RuntimeContext, e: ZEvent) !void {
        const active_scene = self.getActiveScene() orelse return SceneManagerError.NoActiveScene;
        try active_scene.onEvent(ctx, e);
    }

    pub fn initScene(self: *SceneManager, ctx: *RuntimeContext) !void {
        const active_scene = self.getActiveScene() orelse return SceneManagerError.NoActiveScene;
        try active_scene.onStartup(ctx);
    }

    pub fn deinitScene(self: *SceneManager, ctx: *RuntimeContext) !void {
        const active_scene = self.getActiveScene() orelse return SceneManagerError.NoActiveScene;
        try active_scene.onCleanup(ctx);
    }
};

test "SceneManager reports operations without an active scene" {
    const manager = try SceneManager.init(std.testing.allocator);
    var ctx: RuntimeContext = undefined;
    defer manager.deinit(&ctx) catch {};

    try std.testing.expectError(SceneManagerError.NoActiveScene, manager.initScene(&ctx));
    try std.testing.expectError(SceneManagerError.NoActiveScene, manager.updateScene(&ctx, 0.016));
}

const LifecycleTestScene = struct {
    var startup_calls: usize = 0;
    var update_calls: usize = 0;
    var event_calls: usize = 0;
    var cleanup_calls: usize = 0;

    fn reset() void {
        startup_calls = 0;
        update_calls = 0;
        event_calls = 0;
        cleanup_calls = 0;
    }

    pub fn onStartup(_: *LifecycleTestScene, _: *RuntimeContext) !void {
        startup_calls += 1;
    }

    pub fn onUpdate(_: *LifecycleTestScene, _: *RuntimeContext, _: f32) !void {
        update_calls += 1;
    }

    pub fn onEvent(_: *LifecycleTestScene, _: *RuntimeContext, _: ZEvent) !void {
        event_calls += 1;
    }

    pub fn onCleanup(_: *LifecycleTestScene, _: *RuntimeContext) !void {
        cleanup_calls += 1;
    }
};

const CleanupFailureTestScene = struct {
    var cleanup_calls: usize = 0;

    pub fn onStartup(_: *CleanupFailureTestScene, _: *RuntimeContext) !void {}
    pub fn onUpdate(_: *CleanupFailureTestScene, _: *RuntimeContext, _: f32) !void {}
    pub fn onEvent(_: *CleanupFailureTestScene, _: *RuntimeContext, _: ZEvent) !void {}
    pub fn onCleanup(_: *CleanupFailureTestScene, _: *RuntimeContext) !void {
        cleanup_calls += 1;
        return error.TestCleanupFailure;
    }
};

fn testContext(assets: *AssetManager) RuntimeContext {
    return .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .assets = assets,
    };
}

test "SceneManager dispatches scene lifecycle callbacks" {
    LifecycleTestScene.reset();
    var assets: AssetManager = undefined;
    var ctx = testContext(&assets);
    const manager = try SceneManager.init(std.testing.allocator);

    try manager.addScene(LifecycleTestScene, true);
    try manager.initScene(&ctx);
    try manager.updateScene(&ctx, 0.016);
    try manager.handleEvent(&ctx, .WindowClose);
    try manager.deinit(&ctx);

    try std.testing.expectEqual(@as(usize, 1), LifecycleTestScene.startup_calls);
    try std.testing.expectEqual(@as(usize, 1), LifecycleTestScene.update_calls);
    try std.testing.expectEqual(@as(usize, 1), LifecycleTestScene.event_calls);
    try std.testing.expectEqual(@as(usize, 1), LifecycleTestScene.cleanup_calls);
}

test "SceneManager cleans every scene when a cleanup callback fails" {
    LifecycleTestScene.reset();
    CleanupFailureTestScene.cleanup_calls = 0;
    var assets: AssetManager = undefined;
    var ctx = testContext(&assets);
    const manager = try SceneManager.init(std.testing.allocator);

    try manager.addScene(CleanupFailureTestScene, true);
    try manager.addScene(LifecycleTestScene, false);
    try std.testing.expectError(error.TestCleanupFailure, manager.deinit(&ctx));

    try std.testing.expectEqual(@as(usize, 1), CleanupFailureTestScene.cleanup_calls);
    try std.testing.expectEqual(@as(usize, 1), LifecycleTestScene.cleanup_calls);
}
