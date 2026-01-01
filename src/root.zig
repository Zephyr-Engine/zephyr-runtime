const builtin = @import("builtin");
const std = @import("std");
const math = @import("zlm").as(f32);

pub const Application = @import("core/application.zig").Application;

const scene = @import("core/scene.zig");
pub const Scene = scene.Scene;
pub const SceneManager = scene.SceneManager;

const event = @import("core/event.zig");
pub const ZEvent = event.ZEvent;
pub const Key = event.Key;
pub const MouseButton = event.MouseButton;

pub const Shader = @import("graphics/opengl_shader.zig").Shader;
pub const VertexArray = @import("graphics/opengl_vertex_array.zig").VertexArray;

pub const c = @import("c.zig");
pub const gl = c.glad;

pub const recommended_std_options: std.Options = .{
    .log_level = if (builtin.mode == .ReleaseFast) .err else .debug,
    .logFn = @import("core/log.zig").log,
};

pub const Input = &@import("core/input.zig").Input;

pub const Vec3 = math.Vec3;
pub const Vec2 = math.Vec2;
pub const Mat2 = math.Mat2;
pub const Mat3 = math.Mat3;
pub const Mat4 = math.Mat4;

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("core/time.zig");
    _ = @import("core/scene.zig");
    _ = @import("core/event.zig");
    _ = @import("core/input.zig");
}
