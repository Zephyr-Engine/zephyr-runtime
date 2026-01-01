const std = @import("std");
const event = @import("event.zig");

pub fn isScene(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .@"struct") return false;

    const has_onStartup = @hasDecl(T, "onStartup");
    const has_onUpdate = @hasDecl(T, "onUpdate");
    const has_onEvent = @hasDecl(T, "onEvent");
    const has_onCleanup = @hasDecl(T, "onCleanup");

    return has_onStartup and has_onUpdate and has_onEvent and has_onCleanup;
}

pub const Scene = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        onStartup: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) anyerror!void,
        onUpdate: *const fn (ptr: *anyopaque, delta_time: f32) void,
        onEvent: *const fn (ptr: *anyopaque, e: event.ZEvent) void,
        onCleanup: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
    };

    pub fn init(scene_ptr: anytype) Scene {
        const T = @TypeOf(scene_ptr.*);

        if (!comptime isScene(T)) {
            @compileError("Type " ++ @typeName(T) ++ " does not implement Scene interface. " ++
                "Required methods: onStartup, onUpdate, onEvent, onCleanup");
        }

        const gen = struct {
            fn onStartup(ptr: *anyopaque, allocator: std.mem.Allocator) anyerror!void {
                const self: *T = @ptrCast(@alignCast(ptr));
                return self.onStartup(allocator);
            }

            fn onUpdate(ptr: *anyopaque, delta_time: f32) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                self.onUpdate(delta_time);
            }

            fn onEvent(ptr: *anyopaque, e: event.ZEvent) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                self.onEvent(e);
            }

            fn onCleanup(ptr: *anyopaque, allocator: std.mem.Allocator) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                self.onCleanup(allocator);
            }
        };

        const vtable = &VTable{
            .onStartup = gen.onStartup,
            .onUpdate = gen.onUpdate,
            .onEvent = gen.onEvent,
            .onCleanup = gen.onCleanup,
        };

        return Scene{
            .ptr = @ptrCast(scene_ptr),
            .vtable = vtable,
        };
    }

    pub fn onStartup(self: Scene, allocator: std.mem.Allocator) !void {
        return self.vtable.onStartup(self.ptr, allocator);
    }

    pub fn onUpdate(self: Scene, delta_time: f32) void {
        self.vtable.onUpdate(self.ptr, delta_time);
    }

    pub fn onEvent(self: Scene, e: event.ZEvent) void {
        self.vtable.onEvent(self.ptr, e);
    }

    pub fn onCleanup(self: Scene, allocator: std.mem.Allocator) void {
        self.vtable.onCleanup(self.ptr, allocator);
    }
};

pub const SceneManager = struct {
    scenes: std.ArrayList(Scene),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SceneManager {
        return SceneManager{
            .scenes = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SceneManager) void {
        while (self.scenes.items.len > 0) {
            _ = self.popScene();
        }
        self.scenes.deinit(self.allocator);
    }

    pub fn pushScene(self: *SceneManager, scene: Scene) !void {
        try scene.onStartup(self.allocator);
        try self.scenes.append(self.allocator, scene);
    }

    pub fn popScene(self: *SceneManager) ?Scene {
        if (self.scenes.items.len == 0) {
            return null;
        }

        const last_index = self.scenes.items.len - 1;
        const scene = self.scenes.items[last_index];
        _ = self.scenes.pop();

        scene.onCleanup(self.allocator);
        return scene;
    }

    pub fn currentScene(self: *SceneManager) ?Scene {
        if (self.scenes.items.len == 0) {
            return null;
        }
        return self.scenes.items[self.scenes.items.len - 1];
    }

    pub fn update(self: *SceneManager, delta_time: f32) void {
        if (self.currentScene()) |scene| {
            scene.onUpdate(delta_time);
        }
    }

    pub fn handleEvent(self: *SceneManager, e: event.ZEvent) void {
        var i: usize = self.scenes.items.len;
        while (i > 0) {
            i -= 1;
            const scene = self.scenes.items[i];
            scene.onEvent(e);
        }
    }

    pub fn hasScenes(self: *SceneManager) bool {
        return self.scenes.items.len > 0;
    }

    pub fn sceneCount(self: *SceneManager) usize {
        return self.scenes.items.len;
    }
};

test "SceneManager initialization" {
    const allocator = std.testing.allocator;
    var manager = SceneManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(!manager.hasScenes());
    try std.testing.expectEqual(@as(usize, 0), manager.sceneCount());
    try std.testing.expectEqual(@as(?Scene, null), manager.currentScene());
}

const TestScene = struct {
    startup_called: bool = false,
    update_called: bool = false,
    event_called: bool = false,
    cleanup_called: bool = false,
    last_delta: f32 = 0.0,

    pub fn onStartup(self: *TestScene, allocator: std.mem.Allocator) !void {
        _ = allocator;
        self.startup_called = true;
    }

    pub fn onUpdate(self: *TestScene, delta_time: f32) void {
        self.update_called = true;
        self.last_delta = delta_time;
    }

    pub fn onEvent(self: *TestScene, e: event.ZEvent) void {
        _ = e;
        self.event_called = true;
    }

    pub fn onCleanup(self: *TestScene, allocator: std.mem.Allocator) void {
        _ = allocator;
        self.cleanup_called = true;
    }
};

test "Scene interface validation" {
    try std.testing.expect(isScene(TestScene));

    const NotAScene = struct {
        value: i32,
    };
    try std.testing.expect(!isScene(NotAScene));
}

test "SceneManager push and pop scenes" {
    const allocator = std.testing.allocator;
    var manager = SceneManager.init(allocator);
    defer manager.deinit();

    var test_scene = TestScene{};
    const scene = Scene.init(&test_scene);

    try manager.pushScene(scene);
    try std.testing.expect(test_scene.startup_called);
    try std.testing.expect(manager.hasScenes());
    try std.testing.expectEqual(@as(usize, 1), manager.sceneCount());

    const popped = manager.popScene();
    try std.testing.expect(popped != null);
    try std.testing.expect(test_scene.cleanup_called);
    try std.testing.expect(!manager.hasScenes());
}

test "SceneManager update calls current scene" {
    const allocator = std.testing.allocator;
    var manager = SceneManager.init(allocator);
    defer manager.deinit();

    var test_scene = TestScene{};
    const scene = Scene.init(&test_scene);

    try manager.pushScene(scene);
    manager.update(0.016);

    try std.testing.expect(test_scene.update_called);
    try std.testing.expectEqual(@as(f32, 0.016), test_scene.last_delta);
}

test "SceneManager handleEvent propagates to all scenes" {
    const allocator = std.testing.allocator;
    var manager = SceneManager.init(allocator);
    defer manager.deinit();

    var scene1 = TestScene{};
    var scene2 = TestScene{};

    try manager.pushScene(Scene.init(&scene1));
    try manager.pushScene(Scene.init(&scene2));

    const test_event = event.ZEvent.WindowClose;
    manager.handleEvent(test_event);

    try std.testing.expect(scene1.event_called);
    try std.testing.expect(scene2.event_called);
}

test "SceneManager multiple scenes stack behavior" {
    const allocator = std.testing.allocator;
    var manager = SceneManager.init(allocator);
    defer manager.deinit();

    var scene1 = TestScene{};
    var scene2 = TestScene{};
    var scene3 = TestScene{};

    try manager.pushScene(Scene.init(&scene1));
    try manager.pushScene(Scene.init(&scene2));
    try manager.pushScene(Scene.init(&scene3));

    try std.testing.expectEqual(@as(usize, 3), manager.sceneCount());

    manager.update(0.1);
    try std.testing.expect(!scene1.update_called);
    try std.testing.expect(!scene2.update_called);
    try std.testing.expect(scene3.update_called);

    _ = manager.popScene();
    try std.testing.expectEqual(@as(usize, 2), manager.sceneCount());
    try std.testing.expect(scene3.cleanup_called);
}
