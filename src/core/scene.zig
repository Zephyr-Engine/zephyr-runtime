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
            .scenes = .{
                .items = &.{},
                .capacity = 0,
            },
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
        if (self.scenes.items.len == 0) return null;

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
