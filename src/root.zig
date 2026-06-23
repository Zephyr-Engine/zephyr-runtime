pub const RuntimeContext = @import("core/runtime_context.zig").RuntimeContext;
pub const Application = @import("core/application.zig").Application;
pub const VertexArray = @import("graphics/opengl/vertex_array.zig").VertexArray;
pub const Framebuffer = @import("graphics/opengl/framebuffer.zig").Framebuffer;
pub const RenderViewport = @import("core/runtime_context.zig").RenderViewport;
pub const Texture = @import("graphics/opengl/texture.zig").Texture2D;
pub const Shader = @import("graphics/opengl/shader.zig").Shader;
pub const Material = @import("graphics/material.zig").Material;
pub const CursorKind = @import("core/window.zig").CursorKind;
pub const Input = @import("core/input.zig").InputState;
pub const Window = @import("core/window.zig").Window;
pub const ZEvent = @import("core/event.zig").ZEvent;
pub const Mesh = @import("graphics/mesh.zig").Mesh;

pub const AssetManager = @import("assets/asset_manager.zig").AssetManager;
pub const AssetState = @import("assets/asset_manager.zig").AssetState;
pub const AssetRoots = @import("assets/source.zig").AssetRoots;
pub const AssetError = @import("assets/source.zig").AssetError;
pub const AssetKind = @import("assets/uuid.zig").AssetKind;
pub const AssetRef = @import("assets/uuid.zig").AssetRef;
pub const AssetId = @import("assets/uuid.zig").AssetId;
pub const Uuid = @import("assets/uuid.zig").Uuid;

const math = @import("core/math.zig");
pub const Vec3 = math.Vec3;
pub const Vec2 = math.Vec2;
pub const Mat4 = math.Mat4;
pub const Mat3 = math.Mat3;
pub const Mat2 = math.Mat2;
pub const Quat = math.Quat;

const camera = @import("scene/camera.zig");

pub const Renderer = @import("graphics/renderer.zig").Renderer;
pub const setActiveCamera = camera.setActive;
pub const activeCamera = camera.active;
pub const ActiveCamera = camera.ActiveCamera;

pub const components = @import("ecs/components.zig");
pub const ecs = @import("ecs/world.zig");
pub const GameEcs = ecs.GameEcs;

const zimp = @import("zimp");
const zcs = @import("zcs");

pub const FrameCount = zcs.FrameCount;
pub const DeltaTime = zcs.DeltaTime;
pub const ZShader = zimp.ZShader;
pub const ZMesh = zimp.ZMesh;
pub const Zatex = zimp.Zatex;
pub const Zamat = zimp.Zamat;

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("ecs/world.zig");
    _ = @import("core/time.zig");
    _ = @import("core/math.zig");
    _ = @import("core/event.zig");
    _ = @import("core/input.zig");
    _ = @import("scene/scene.zig");
    _ = @import("assets/uuid.zig");
    _ = @import("scene/camera.zig");
    _ = @import("scene/manager.zig");
    _ = @import("assets/source.zig");
    _ = @import("ecs/components.zig");
    _ = @import("assets/asset_manager.zig");
    _ = @import("core/runtime_context.zig");
    _ = @import("core/runtime_context.zig");
    _ = @import("graphics/opengl/framebuffer.zig");
    _ = @import("graphics/opengl/diagnostics.zig");
    _ = @import("graphics/layout.zig");
}
