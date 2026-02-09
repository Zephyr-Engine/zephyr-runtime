const std = @import("std");
const AssetManager = @import("../asset/manager.zig").AssetManager;
const Camera = @import("../scene/camera.zig").Camera;
const Model = @import("../asset/model.zig").Model;
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const math = @import("zlm").as(f32);
const c = @import("../c.zig");
const gl = c.glad;

pub const RenderCommand = struct {
    pub fn Draw(camera: *Camera) void {
        for (AssetManager.GetModels(), 0..) |model, i| {
            const modelMatrix = AssetManager.GetWorldMatrix(i);
            model.material.setUniform("r_position", modelMatrix.mul(camera.viewProjectionMatrix()));
            model.material.setUniform("r_viewPos", camera.position);

            model.material.setUniform("r_model", modelMatrix);
            model.material.setUniform("material.ambient", model.material.lighting.ambient);
            model.material.setUniform("material.diffuse", model.material.lighting.diffuse);
            model.material.setUniform("material.specular", model.material.lighting.specular);
            model.material.setUniform("material.shininess", model.material.lighting.shininess);
            model.draw();
        }
    }

    pub fn Clear(color: math.Vec3) void {
        gl.glClearColor(color.x, color.y, color.z, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
    }

    pub fn SetViewport(x: i32, y: i32, width: i32, height: i32) void {
        gl.glViewport(x, y, width, height);
    }

    pub fn EnableMultisample() void {
        gl.glEnable(gl.GL_MULTISAMPLE);
    }

    pub fn DisableMultisample() void {
        gl.glDisable(gl.GL_MULTISAMPLE);
    }

    pub fn DrawPicking(camera: *Camera, shader: *Shader) void {
        shader.bind();
        const vp = camera.viewProjectionMatrix();

        for (AssetManager.GetModels(), 0..) |model, i| {
            const model_mat = AssetManager.GetWorldMatrix(i);
            const mvp = model_mat.mul(vp);
            shader.setUniform("u_mvp", mvp);
            shader.setUniform("u_objectId", @as(i32, @intCast(i)));
            model.vao.draw();
        }
    }

    pub fn DrawOutline(camera: *Camera, model_index: usize, shader: *Shader, outline_color: math.Vec3, scale_factor: f32) void {
        shader.bind();

        const models = AssetManager.GetModels();
        if (model_index >= models.len) return;
        const model = models[model_index];

        const model_mat = AssetManager.GetWorldMatrix(model_index);
        const vp = camera.viewProjectionMatrix();

        // Clear stencil buffer before outline pass
        gl.glClear(gl.GL_STENCIL_BUFFER_BIT);

        // --- Pass 1: Write selected model to stencil ---
        gl.glEnable(gl.GL_STENCIL_TEST);
        gl.glDepthFunc(gl.GL_LEQUAL);
        gl.glStencilFunc(gl.GL_ALWAYS, 1, 0xFF);
        gl.glStencilOp(gl.GL_KEEP, gl.GL_KEEP, gl.GL_REPLACE);
        gl.glStencilMask(0xFF);
        gl.glColorMask(gl.GL_FALSE, gl.GL_FALSE, gl.GL_FALSE, gl.GL_FALSE);
        gl.glDepthMask(gl.GL_FALSE);

        const mvp_normal = model_mat.mul(vp);
        shader.setUniform("u_mvp", mvp_normal);
        shader.setUniform("u_outlineColor", outline_color);
        model.vao.draw();

        // --- Pass 2: Render scaled-up model where stencil != 1 ---
        gl.glStencilFunc(gl.GL_NOTEQUAL, 1, 0xFF);
        gl.glStencilMask(0x00);
        gl.glColorMask(gl.GL_TRUE, gl.GL_TRUE, gl.GL_TRUE, gl.GL_TRUE);
        gl.glDepthMask(gl.GL_FALSE);
        gl.glDisable(gl.GL_DEPTH_TEST);

        const scale_mat = math.Mat4.createScale(scale_factor, scale_factor, scale_factor);
        const scaled_model_mat = model_mat.mul(scale_mat);
        const mvp_scaled = scaled_model_mat.mul(vp);
        shader.setUniform("u_mvp", mvp_scaled);
        shader.setUniform("u_outlineColor", outline_color);
        model.vao.draw();

        // --- Restore GL state ---
        gl.glStencilMask(0xFF);
        gl.glStencilFunc(gl.GL_ALWAYS, 0, 0xFF);
        gl.glEnable(gl.GL_DEPTH_TEST);
        gl.glDepthFunc(gl.GL_LESS);
        gl.glDepthMask(gl.GL_TRUE);
        gl.glDisable(gl.GL_STENCIL_TEST);
    }
};
