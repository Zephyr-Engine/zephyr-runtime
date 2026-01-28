const builtin = @import("builtin");
const std = @import("std");

// C bindings (for OpenGL access)
pub const c = @import("c.zig");

const application = @import("core/application.zig");
pub const Application = application.Application;
pub const ApplicationProps = application.ApplicationProps;

pub const Window = @import("core/window.zig").Window;

const scene = @import("core/scene.zig");
pub const Scene = scene.Scene;
pub const SceneManager = scene.SceneManager;

const event = @import("core/event.zig");
pub const ZEvent = event.ZEvent;
pub const Key = event.Key;
pub const MouseButton = event.MouseButton;

pub const RenderCommand = @import("core/renderer.zig").RenderCommand;
pub const material = @import("asset/material.zig");
pub const Material = material.Material;
pub const MaterialInstance = material.MaterialInstance;
pub const MaterialLighting = material.Lighting;
pub const Light = @import("asset/light.zig").Light;

pub const Shader = @import("graphics/opengl_shader.zig").Shader;
pub const VertexArray = @import("graphics/opengl_vertex_array.zig").VertexArray;

pub const Texture = @import("graphics/opengl_texture.zig").Texture;
pub const TextureFormat = @import("graphics/opengl_texture.zig").TextureFormat;
pub const Framebuffer = @import("graphics/opengl_framebuffer.zig").Framebuffer;

pub const recommended_std_options: std.Options = .{
    .log_level = if (builtin.mode == .ReleaseFast) .err else .debug,
    .logFn = @import("core/log.zig").log,
};

pub const Input = @import("core/input.zig").InputManager;

const math = @import("core/math.zig");
pub const Vec3 = math.Vec3;
pub const Vec2 = math.Vec2;
pub const Mat2 = math.Mat2;
pub const Mat3 = math.Mat3;
pub const Mat4 = math.Mat4;

pub const Model = @import("asset/model.zig").Model;

pub const Camera = @import("scene/camera.zig").Camera;

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("core/time.zig");
    _ = @import("core/scene.zig");
    _ = @import("core/event.zig");
    _ = @import("core/input.zig");
    _ = @import("scene/camera.zig");
}
