const std = @import("std");
const ZEvent = @import("../core/event.zig").ZEvent;
const RuntimeContext = @import("../core/runtime_context.zig").RuntimeContext;
const log = @import("../core/log.zig");

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
                defer ctx.allocator.destroy(self);
                try T.onCleanup(self, ctx);
            }
        };

        const instance = allocator.create(T) catch |err| {
            log.err("failed to allocate scene instance: {}", .{err});
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

var test_call_log: [8]u8 = undefined;
var test_call_count: usize = 0;

fn recordCall(tag: u8) void {
    test_call_log[test_call_count] = tag;
    test_call_count += 1;
}

const RecordingScene = struct {
    fn onStartup(_: *RecordingScene, _: *RuntimeContext) !void {
        recordCall('S');
    }
    fn onUpdate(_: *RecordingScene, _: *RuntimeContext, _: f32) !void {
        recordCall('U');
    }
    fn onEvent(_: *RecordingScene, _: *RuntimeContext, _: ZEvent) !void {
        recordCall('E');
    }
    fn onCleanup(_: *RecordingScene, _: *RuntimeContext) !void {
        recordCall('C');
    }
};

const FailingScene = struct {
    fn onStartup(_: *FailingScene, _: *RuntimeContext) !void {
        return error.Boom;
    }
    fn onUpdate(_: *FailingScene, _: *RuntimeContext, _: f32) !void {}
    fn onEvent(_: *FailingScene, _: *RuntimeContext, _: ZEvent) !void {}
    fn onCleanup(_: *FailingScene, _: *RuntimeContext) !void {}
};

fn fakeContext() RuntimeContext {
    // The recording scenes never touch these fields; only the allocator (used by
    // onCleanup to free the instance) needs to be real.
    return .{
        .allocator = std.testing.allocator,
        .io = undefined,
        .assets = undefined,
        .world = undefined,
    };
}

test "Scene forwards lifecycle calls to the implementation in order" {
    test_call_count = 0;
    var scene = try Scene.init(RecordingScene, std.testing.allocator, true);
    try std.testing.expect(scene.is_active);

    var ctx = fakeContext();
    try scene.onStartup(&ctx);
    try scene.onUpdate(&ctx, 0.016);
    try scene.onEvent(&ctx, .WindowClose);
    // onCleanup frees the heap instance; testing.allocator flags a leak otherwise.
    try scene.onCleanup(&ctx);

    try std.testing.expectEqualStrings("SUEC", test_call_log[0..test_call_count]);
}

test "Scene propagates errors raised by the implementation" {
    var scene = try Scene.init(FailingScene, std.testing.allocator, false);
    try std.testing.expect(!scene.is_active);

    var ctx = fakeContext();
    try std.testing.expectError(error.Boom, scene.onStartup(&ctx));
    try scene.onCleanup(&ctx);
}
