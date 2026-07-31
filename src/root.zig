pub const Application = @import("core/application.zig").Application;
pub const Runtime = @import("core/runtime.zig").Runtime;
pub const VertexArray = @import("graphics/opengl/vertex_array.zig").VertexArray;
pub const Framebuffer = @import("graphics/opengl/framebuffer.zig").Framebuffer;
pub const Texture = @import("graphics/opengl/texture.zig").Texture2D;
pub const Shader = @import("graphics/opengl/shader.zig").Shader;
pub const Material = @import("graphics/material.zig").Material;
pub const CursorKind = @import("core/window.zig").CursorKind;
pub const MouseButton = @import("core/event.zig").MouseButton;
pub const Window = @import("core/window.zig").Window;
pub const ZEvent = @import("core/event.zig").ZEvent;
pub const Mesh = @import("graphics/mesh.zig").Mesh;
pub const Input = @import("core/input.zig").Input;
pub const Key = @import("core/event.zig").Key;

pub const AssetManager = @import("assets/asset_manager.zig").AssetManager;
pub const AssetError = @import("assets/source.zig").AssetError;
pub const Uuid = zimp.Uuid;
pub const ProjectId = zimp.ProjectId;
pub const AssetId = zimp.AssetId;
pub const SceneId = zimp.SceneId;
pub const SceneEntityId = zimp.SceneEntityId;
pub const ComponentTypeId = zimp.ComponentTypeId;
pub const SchemaId = zimp.SchemaId;

const math = @import("core/math.zig");
pub const Vec3 = math.Vec3;
pub const Vec2 = math.Vec2;
pub const Mat4 = math.Mat4;
pub const Mat3 = math.Mat3;
pub const Mat2 = math.Mat2;
pub const Quat = math.Quat;

pub const scene_schema = struct {
    pub const SceneRuntimeInstance = @import("scene/runtime_instance.zig").SceneRuntimeInstance;
    pub const ComponentCodec = @import("scene/component_codec.zig").ComponentCodec;
    pub const SchemaRegistry = @import("scene/schema_registry.zig").SchemaRegistry;
    pub const CodecError = @import("scene/component_codec.zig").CodecError;
    pub const SchemaMeta = zimp.scene.SchemaMeta;

    const derive_schema = @import("scene/derive_schema.zig");
    pub const deriveCodec = derive_schema.deriveCodec;
    pub const deriveSchema = derive_schema.deriveSchema;
};

const camera = @import("scene/camera.zig");

pub const setActiveCamera = camera.setActive;
pub const activeCamera = camera.active;
pub const ActiveCamera = camera.ActiveCamera;

pub const ProjectManifest = zimp.ProjectManifest;
pub const Project = @import("project/project.zig").Project;
pub const openProject = @import("project/open.zig").open;

pub const Renderer = @import("graphics/renderer.zig").Renderer;
pub const RenderViewport = Renderer.RenderViewport;
pub const RenderTarget = Renderer.RenderTarget;
pub const DebugStats = @import("graphics/debug_stats.zig").DebugStats;
pub const Game = @import("core/game.zig").Game;

pub const components = @import("ecs/components.zig");
pub const ecs = @import("ecs/world.zig");

const zimp = @import("zimp");
const zcs = @import("zcs");

pub const FrameCount = zcs.FrameCount;
pub const DeltaTime = zcs.DeltaTime;
pub const World = zcs.World;
pub const CommandBuffer = zcs.CommandBuffer;
pub const Schedule = zcs.Schedule;
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
    _ = @import("scene/camera.zig");
    _ = @import("scene/component_codec.zig");
    _ = @import("scene/derive_schema.zig");
    _ = @import("scene/schema_registry.zig");
    _ = @import("assets/source.zig");
    _ = @import("assets/manifest.zig");
    _ = @import("ecs/components.zig");
    _ = @import("assets/asset_manager.zig");
    _ = @import("core/runtime.zig");
    _ = @import("scene/controller.zig");
    _ = @import("graphics/opengl/framebuffer.zig");
    _ = @import("graphics/opengl/diagnostics.zig");
    _ = @import("graphics/debug_stats.zig");
    _ = @import("graphics/layout.zig");
    _ = @import("project/project.zig");
    _ = @import("project/open.zig");
}
