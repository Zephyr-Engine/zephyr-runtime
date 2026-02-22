const std = @import("std");
const Framebuffer = @import("../graphics/opengl_framebuffer.zig").Framebuffer;
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const AssetManager = @import("../asset/manager.zig").AssetManager;
const Light = @import("../asset/light.zig").Light;
const LightKind = @import("../asset/light.zig").LightKind;
const math = @import("zlm").as(f32);
const c = @import("../c.zig");
const gl = c.glad;

pub const ShadowMapError = error{
    ShaderCreationFailed,
    FramebufferCreationFailed,
    OutOfMemory,
};

pub const ShadowMap = struct {
    framebuffer: Framebuffer,
    shader: Shader,
    light_space_matrix: math.Mat4,
    resolution: i32,
    shadow_distance: f32,

    const shadow_vs = @embedFile("../graphics/shaders/shadow_vertex.glsl");
    const shadow_fs = @embedFile("../graphics/shaders/shadow_fragment.glsl");

    pub fn init(allocator: std.mem.Allocator, resolution: i32, shadow_distance: f32) ShadowMapError!ShadowMap {
        const fb = Framebuffer.initDepthOnly(resolution, resolution) catch {
            return ShadowMapError.FramebufferCreationFailed;
        };

        const shader = Shader.init(allocator, shadow_vs, shadow_fs) catch {
            return ShadowMapError.ShaderCreationFailed;
        };

        return .{
            .framebuffer = fb,
            .shader = shader,
            .light_space_matrix = math.Mat4.identity,
            .resolution = resolution,
            .shadow_distance = shadow_distance,
        };
    }

    pub fn deinit(self: *ShadowMap) void {
        self.framebuffer.deinit();
        self.shader.deinit();
    }

    pub fn computeLightSpaceMatrix(self: *ShadowMap, light: Light) void {
        const dist = self.shadow_distance;

        switch (light.kind) {
            .directional => {
                const light_dir = math.Vec3.normalize(light.direction);
                const light_pos = light_dir.scale(-dist);
                const light_view = math.Mat4.createLookAt(
                    light_pos,
                    .{ .x = 0, .y = 0, .z = 0 },
                    .{ .x = 0, .y = 1, .z = 0 },
                );
                const light_proj = math.Mat4.createOrthogonal(-dist, dist, -dist, dist, 0.1, dist * 2.0);
                self.light_space_matrix = light_view.mul(light_proj);
            },
            .point => {
                const light_view = math.Mat4.createLookAt(
                    light.position,
                    .{ .x = 0, .y = 0, .z = 0 },
                    .{ .x = 0, .y = 1, .z = 0 },
                );
                const light_proj = math.Mat4.createPerspective(std.math.pi / 2.0, 1.0, 0.1, dist);
                self.light_space_matrix = light_view.mul(light_proj);
            },
            .spot => {
                const target = light.position.add(light.direction);
                const light_view = math.Mat4.createLookAt(
                    light.position,
                    target,
                    .{ .x = 0, .y = 1, .z = 0 },
                );
                const fov = std.math.acos(light.outer_cut_off) * 2.0;
                const light_proj = math.Mat4.createPerspective(fov, 1.0, 0.1, dist);
                self.light_space_matrix = light_view.mul(light_proj);
            },
        }
    }

    pub fn renderShadowPass(self: *ShadowMap) void {
        self.framebuffer.bind();
        gl.glClear(gl.GL_DEPTH_BUFFER_BIT);

        // Cull front faces to reduce shadow acne
        gl.glCullFace(gl.GL_FRONT);
        gl.glEnable(gl.GL_CULL_FACE);

        self.shader.bind();
        self.shader.setUniform("u_lightSpaceMatrix", self.light_space_matrix);

        const models = AssetManager.GetModels();
        for (models, 0..) |model, i| {
            const model_matrix = AssetManager.GetWorldMatrix(i);
            self.shader.setUniform("r_model", model_matrix);
            model.vao.draw();
        }

        // Restore cull mode
        gl.glCullFace(gl.GL_BACK);

        Framebuffer.unbind();
    }

    pub fn getDepthTexture(self: ShadowMap) u32 {
        return self.framebuffer.getDepthTexture();
    }

    pub fn getLightSpaceMatrix(self: ShadowMap) math.Mat4 {
        return self.light_space_matrix;
    }
};
