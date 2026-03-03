const builtin = @import("builtin");
const std = @import("std");

const application = @import("core/application.zig");
pub const Application = application.Application;
pub const ApplicationProps = application.ApplicationProps;

const window = @import("core/window.zig");
pub const Window = window.Window;
pub const Cursor = window.Cursor;
pub const CursorShape = window.CursorShape;

pub const Time = @import("core/time.zig").Time;

const scene = @import("core/scene.zig");
pub const Scene = scene.Scene;
pub const SceneManager = scene.SceneManager;

const event = @import("core/event.zig");
pub const ZEvent = event.ZEvent;
pub const Key = event.Key;
pub const MouseButton = event.MouseButton;

const renderer = @import("core/renderer.zig");
pub const RenderCommand = renderer.RenderCommand;
pub const RenderPass = renderer.RenderPass;
pub const RenderPipeline = renderer.RenderPipeline;
pub const ClearFlags = renderer.ClearFlags;
pub const ShadowMap = @import("core/shadow_map.zig").ShadowMap;
pub const PostProcessPipeline = @import("core/post_process.zig").PostProcessPipeline;
const draw_list_mod = @import("core/draw_list.zig");
pub const DrawList = draw_list_mod.DrawList;
pub const DrawCommand = draw_list_mod.DrawCommand;
pub const material = @import("asset/material.zig");
pub const Material = material.Material;
pub const MaterialInstance = material.MaterialInstance;
pub const MaterialLighting = material.Lighting;
pub const Light = @import("asset/light.zig").Light;
pub const LightKind = @import("asset/light.zig").LightKind;

pub const Shader = @import("graphics/opengl_shader.zig").Shader;
pub const VertexArray = @import("graphics/opengl_vertex_array.zig").VertexArray;

pub const Texture = @import("graphics/opengl_texture.zig").Texture;
pub const TextureFormat = @import("graphics/opengl_texture.zig").TextureFormat;
const framebuffer_mod = @import("graphics/opengl_framebuffer.zig");
pub const Framebuffer = framebuffer_mod.Framebuffer;
pub const FramebufferConfig = framebuffer_mod.FramebufferConfig;
pub const AttachmentFormat = framebuffer_mod.AttachmentFormat;
pub const fullscreen_quad = @import("graphics/fullscreen_quad.zig");

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
pub const LightHandle = asset.LightHandle;
pub const CameraHandle = asset.CameraHandle;

const math = @import("core/math.zig");
pub const Vec3 = math.Vec3;
pub const Vec2 = math.Vec2;
pub const Mat2 = math.Mat2;
pub const Mat3 = math.Mat3;
pub const Mat4 = math.Mat4;

pub const Model = @import("asset/model.zig").Model;
pub const gltf = @import("asset/gltf.zig");
pub const Transform = @import("asset/transform.zig").Transform;

pub const GltfPbrDesc = asset.GltfPbrDesc;
pub const ObjDesc = asset.ObjDesc;
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
    _ = @import("core/render_pass.zig");
    _ = @import("core/shadow_map.zig");
    _ = @import("core/post_process.zig");
    _ = @import("core/draw_list.zig");
    _ = @import("graphics/fullscreen_quad.zig");
}
