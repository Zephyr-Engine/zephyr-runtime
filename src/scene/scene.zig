const std = @import("std");
const ZEvent = @import("../core/event.zig").ZEvent;

pub const SceneError = error{
    OutOfMemory,
};

pub const Scene = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    is_active: bool,

    const VTable = struct {
        onStartup: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
        onUpdate: *const fn (ptr: *anyopaque, delta_time: f32) void,
        onEvent: *const fn (ptr: *anyopaque, e: ZEvent) void,
        onCleanup: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
    };

    pub fn init(
        comptime T: type,
        allocator: std.mem.Allocator,
        is_active: bool,
    ) SceneError!Scene {
        comptime validateScene(T);

        const gen = struct {
            fn onStartup(ptr: *anyopaque, alloc: std.mem.Allocator) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                T.onStartup(self, alloc);
            }

            fn onUpdate(ptr: *anyopaque, delta_time: f32) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                T.onUpdate(self, delta_time);
            }

            fn onEvent(ptr: *anyopaque, e: ZEvent) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                T.onEvent(self, e);
            }

            fn onCleanup(ptr: *anyopaque, alloc: std.mem.Allocator) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                T.onCleanup(self, alloc);
                alloc.destroy(self);
            }
        };

        const instance = allocator.create(T) catch |err| {
            std.log.err("Failed to allocate scene instance: {}", .{err});
            return SceneError.OutOfMemory;
        };

        return .{
            .ptr = instance,
            .vtable = &.{
                .onStartup = gen.onStartup,
                .onUpdate = gen.onUpdate,
                .onEvent = gen.onEvent,
                .onCleanup = gen.onCleanup,
            },
            .is_active = is_active,
        };
    }

    pub fn onStartup(self: *Scene, allocator: std.mem.Allocator) void {
        self.vtable.onStartup(self.ptr, allocator);
    }

    pub fn onUpdate(self: *Scene, delta_time: f32) void {
        self.vtable.onUpdate(self.ptr, delta_time);
    }

    pub fn onEvent(self: *Scene, e: ZEvent) void {
        self.vtable.onEvent(self.ptr, e);
    }

    pub fn onCleanup(self: *Scene, allocator: std.mem.Allocator) void {
        self.vtable.onCleanup(self.ptr, allocator);
    }
};

fn validateScene(comptime T: type) void {
    const required_fns = .{
        .{ "onStartup", fn (*T, std.mem.Allocator) void },
        .{ "onUpdate", fn (*T, f32) void },
        .{ "onEvent", fn (*T, ZEvent) void },
        .{ "onCleanup", fn (*T, std.mem.Allocator) void },
    };

    inline for (required_fns) |req| {
        const name = req[0];
        const Sig = req[1];

        if (!@hasDecl(T, name)) {
            @compileError("Scene implementation missing: " ++ name);
        }

        const actual = @TypeOf(@field(T, name));
        if (actual != Sig) {
            @compileError("Scene." ++ name ++ " has wrong signature. Expected: " ++ @typeName(Sig) ++ ", got: " ++ @typeName(actual));
        }
    }
}
