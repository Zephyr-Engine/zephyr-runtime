const std = @import("std");
const c = @import("c.zig");
const glfw = c.glfw;
pub const gl = c.glad;

pub const ZEvent = @import("core/event.zig").ZEvent;
pub const Window = @import("core/window.zig").Window;
pub const Input = @import("core/input.zig").InputManager;
pub const Material = @import("graphics/material.zig").Material;
pub const MeshHandle = @import("graphics/mesh.zig").MeshHandle;
pub const Shader = @import("graphics/opengl/shader.zig").Shader;
pub const Application = @import("core/application.zig").Application;
pub const Texture = @import("graphics/opengl/texture.zig").Texture2D;
pub const VertexArray = @import("graphics/opengl/vertex_array.zig").VertexArray;

const math = @import("core/math.zig");
pub const Vec3 = math.Vec3;
pub const Vec2 = math.Vec2;
pub const Mat4 = math.Mat4;
pub const Mat3 = math.Mat3;
pub const Mat2 = math.Mat2;
pub const Quat = math.Quat;

pub const Camera3D = @import("scene/camera.zig").Camera3D;
pub const EditorCamera = @import("scene/editor_camera.zig").EditorCamera;

const zimp = @import("zimp");
pub const ZMesh = zimp.ZMesh;
pub const ZShader = zimp.ZShader;
pub const Zatex = zimp.Zatex;
pub const Zamat = zimp.Zamat;

pub const recommended_std_options: std.Options = .{
    .logFn = @import("core/log.zig").log,
};

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("core/time.zig");
    _ = @import("core/event.zig");
    _ = @import("core/input.zig");
    _ = @import("core/math.zig");
    _ = @import("scene/scene.zig");
    _ = @import("scene/manager.zig");
    _ = @import("scene/camera.zig");
    _ = @import("scene/editor_camera.zig");
}
