const std = @import("std");
const ZEvent = @import("../core/event.zig").ZEvent;
const RuntimeContext = @import("../core/runtime_context.zig").RuntimeContext;

pub const SceneError = error{
    OutOfMemory,
};

pub const Scene = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    is_active: bool,

    const VTable = struct {
        onStartup: *const fn (
            ptr: *anyopaque,
            ctx: *RuntimeContext,
        ) anyerror!void,
        onUpdate: *const fn (
            ptr: *anyopaque,
            ctx: *RuntimeContext,
            delta_time: f32,
        ) anyerror!void,
        onEvent: *const fn (
            ptr: *anyopaque,
            ctx: *RuntimeContext,
            e: ZEvent,
        ) anyerror!void,
        onCleanup: *const fn (
            ptr: *anyopaque,
            ctx: *RuntimeContext,
        ) anyerror!void,
    };

    pub fn init(
        comptime T: type,
        allocator: std.mem.Allocator,
        is_active: bool,
    ) SceneError!Scene {
        comptime validateScene(T);

        const gen = struct {
            fn onStartup(ptr: *anyopaque, ctx: *RuntimeContext) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                try T.onStartup(self, ctx);
            }

            fn onUpdate(ptr: *anyopaque, ctx: *RuntimeContext, delta_time: f32) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                try T.onUpdate(self, ctx, delta_time);
            }

            fn onEvent(ptr: *anyopaque, ctx: *RuntimeContext, e: ZEvent) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                try T.onEvent(self, ctx, e);
            }

            fn onCleanup(ptr: *anyopaque, ctx: *RuntimeContext) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                try T.onCleanup(self, ctx);
                ctx.allocator.destroy(self);
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

    pub fn onStartup(self: *Scene, ctx: *RuntimeContext) !void {
        try self.vtable.onStartup(self.ptr, ctx);
    }

    pub fn onUpdate(self: *Scene, ctx: *RuntimeContext, delta_time: f32) !void {
        try self.vtable.onUpdate(self.ptr, ctx, delta_time);
    }

    pub fn onEvent(self: *Scene, ctx: *RuntimeContext, e: ZEvent) !void {
        try self.vtable.onEvent(self.ptr, ctx, e);
    }

    pub fn onCleanup(self: *Scene, ctx: *RuntimeContext) !void {
        try self.vtable.onCleanup(self.ptr, ctx);
    }
};

fn validateSceneFn(comptime T: type, comptime name: []const u8, comptime Sig: type) void {
    if (!@hasDecl(T, name)) {
        @compileError("Scene implementation missing: " ++ name);
    }
    const actual = @TypeOf(@field(T, name));
    const expected_info = @typeInfo(Sig).@"fn";
    const actual_info = @typeInfo(actual).@"fn";

    if (actual_info.params.len != expected_info.params.len) {
        @compileError("Scene." ++ name ++ " has wrong number of parameters. Expected: " ++ @typeName(Sig) ++ ", got: " ++ @typeName(actual));
    }

    inline for (actual_info.params, expected_info.params) |ap, ep| {
        if (ap.type != ep.type) {
            @compileError("Scene." ++ name ++ " has wrong parameter types. Expected: " ++ @typeName(Sig) ++ ", got: " ++ @typeName(actual));
        }
    }

    const ret = actual_info.return_type orelse @compileError("Scene." ++ name ++ " must have a return type");
    const ret_info = @typeInfo(ret);
    if (ret_info != .error_union or ret_info.error_union.payload != void) {
        @compileError("Scene." ++ name ++ " must return !void, got: " ++ @typeName(actual));
    }
}

fn validateScene(comptime T: type) void {
    comptime validateSceneFn(T, "onStartup", fn (*T, *RuntimeContext) anyerror!void);
    comptime validateSceneFn(T, "onUpdate", fn (*T, *RuntimeContext, f32) anyerror!void);
    comptime validateSceneFn(T, "onEvent", fn (*T, *RuntimeContext, ZEvent) anyerror!void);
    comptime validateSceneFn(T, "onCleanup", fn (*T, *RuntimeContext) anyerror!void);
}
