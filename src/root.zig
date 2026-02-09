const builtin = @import("builtin");
const std = @import("std");

const application = @import("core/application.zig");
pub const Application = application.Application;
pub const ApplicationProps = application.ApplicationProps;

const window = @import("core/window.zig");
pub const Window = window.Window;
pub const Cursor = window.Cursor;
pub const CursorShape = window.CursorShape;

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

const input_mod = @import("core/input.zig");
pub const Input = input_mod.InputManager;
pub const InputPosition = input_mod.Position;
const asset = @import("asset/manager.zig");
pub const AssetManager = asset.AssetManager;
pub const AssetHandle = asset.AssetHandle;

const math = @import("core/math.zig");
pub const Vec3 = math.Vec3;
pub const Vec2 = math.Vec2;
pub const Mat2 = math.Mat2;
pub const Mat3 = math.Mat3;
pub const Mat4 = math.Mat4;

pub const Model = @import("asset/model.zig").Model;
pub const Transform = @import("asset/transform.zig").Transform;
pub const Quat = @import("core/math.zig").Quat;

pub const Camera = @import("scene/camera.zig").Camera;

pub const SceneSnapshot = @import("core/scene_state.zig").SceneSnapshot;

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("core/time.zig");
    _ = @import("core/scene.zig");
    _ = @import("core/event.zig");
    _ = @import("core/input.zig");
    _ = @import("scene/camera.zig");
    _ = @import("asset/transform.zig");
    _ = @import("core/scene_state.zig");
}
