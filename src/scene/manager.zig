const std = @import("std");
const Scene = @import("scene.zig").Scene;
const ZEvent = @import("../core/event.zig").ZEvent;
const RuntimeContext = @import("../core/runtime_context.zig").RuntimeContext;

pub const SceneManagerError = error{
    OutOfMemory,
};

pub const SceneManager = struct {
    scenes: std.ArrayList(Scene),
    allocator: std.mem.Allocator,
    active_scene_index: usize,

    pub fn init(allocator: std.mem.Allocator) SceneManagerError!*SceneManager {
        const manager = allocator.create(SceneManager) catch |err| {
            std.log.err("Failed to allocate SceneManager: {}", .{err});
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
        const active_scene = self.getActiveScene();
        try active_scene.onCleanup(ctx);
        self.scenes.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub inline fn getActiveScene(self: *const SceneManager) *Scene {
        return &self.scenes.items[self.active_scene_index];
    }

    pub fn addScene(self: *SceneManager, comptime scene: type, is_active: bool) SceneManagerError!void {
        const s = Scene.init(scene, self.allocator, is_active) catch {
            return;
        };

        self.scenes.append(self.allocator, s) catch {
            return SceneManagerError.OutOfMemory;
        };

        if (s.is_active) {
            self.active_scene_index = self.scenes.items.len - 1;
        }
    }

    pub fn updateScene(self: *SceneManager, ctx: *RuntimeContext, delta_time: f32) !void {
        const active_scene = self.getActiveScene();
        try active_scene.onUpdate(ctx, delta_time);
    }

    pub fn handleEvent(self: *SceneManager, ctx: *RuntimeContext, e: ZEvent) !void {
        const active_scene = self.getActiveScene();
        try active_scene.onEvent(ctx, e);
    }

    pub fn initScene(self: *SceneManager, ctx: *RuntimeContext) !void {
        const active_scene = self.getActiveScene();
        try active_scene.onStartup(ctx);
    }

    pub fn deinitScene(self: *SceneManager, ctx: *RuntimeContext) !void {
        const active_scene = self.getActiveScene();
        try active_scene.onCleanup(ctx);
    }
};
