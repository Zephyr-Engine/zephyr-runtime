const builtin = @import("builtin");
const std = @import("std");

const application = @import("core/application.zig");
pub const Application = application.Application;
pub const ApplicationProps = application.ApplicationProps;

const scene = @import("core/scene.zig");
pub const Scene = scene.Scene;
pub const SceneManager = scene.SceneManager;

const event = @import("core/event.zig");
pub const ZEvent = event.ZEvent;
pub const Key = event.Key;
pub const MouseButton = event.MouseButton;

pub const RenderCommand = @import("core/renderer.zig").RenderCommand;
pub const Material = @import("asset/material.zig").Material;
pub const Shader = @import("graphics/opengl_shader.zig").Shader;
pub const VertexArray = @import("graphics/opengl_vertex_array.zig").VertexArray;

pub const recommended_std_options: std.Options = .{
    .log_level = if (builtin.mode == .ReleaseFast) .err else .debug,
    .logFn = @import("core/log.zig").log,
};

pub const Input = &@import("core/input.zig").Input;

const math = @import("core/math.zig");
pub const Vec3 = math.Vec3;
pub const Vec2 = math.Vec2;
pub const Mat2 = math.Mat2;
pub const Mat3 = math.Mat3;
pub const Mat4 = math.Mat4;

pub const Camera = @import("scene/camera.zig").Camera;

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("core/time.zig");
    _ = @import("core/scene.zig");
    _ = @import("core/event.zig");
    _ = @import("core/input.zig");
    _ = @import("scene/camera.zig");
}
