const std = @import("std");
const AssetManager = @import("../asset/manager.zig").AssetManager;
const Camera = @import("../scene/camera.zig").Camera;
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const math = @import("zlm").as(f32);
const c = @import("../c.zig");
const gl = c.glad;

pub const render_pass = @import("render_pass.zig");
pub const RenderPass = render_pass.RenderPass;
pub const RenderPipeline = render_pass.RenderPipeline;
pub const ClearFlags = render_pass.ClearFlags;

pub const RenderCommand = struct {
    pub fn SetViewport(x: i32, y: i32, width: i32, height: i32) void {
        gl.glViewport(x, y, width, height);
    }

    pub fn Clear(color: math.Vec3) void {
        gl.glClearColor(color.x, color.y, color.z, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
    }

    pub fn EnableMultisample() void {
        gl.glEnable(gl.GL_MULTISAMPLE);
    }

    pub fn DisableMultisample() void {
        gl.glDisable(gl.GL_MULTISAMPLE);
    }

    pub fn DrawModel(camera: *Camera, model_index: usize, shader: *Shader) void {
        const models = AssetManager.GetModels();
        if (model_index >= models.len) {
            return;
        }
        const model = models[model_index];

        const model_mat = AssetManager.GetWorldMatrix(model_index);
        const vp = camera.viewProjectionMatrix();
        const mvp = model_mat.mul(vp);
        shader.setUniform("u_mvp", mvp);
        model.vao.draw();
    }

    pub fn DrawStencilOutline(camera: *Camera, model_index: usize, shader: *Shader, scale_factor: f32) void {
        const models = AssetManager.GetModels();
        if (model_index >= models.len) {
            return;
        }
        const model = models[model_index];

        const model_mat = AssetManager.GetWorldMatrix(model_index);
        const vp = camera.viewProjectionMatrix();

        gl.glClear(gl.GL_STENCIL_BUFFER_BIT);

        // Pass 1: Write selected model to stencil
        gl.glEnable(gl.GL_STENCIL_TEST);
        gl.glDepthFunc(gl.GL_LEQUAL);
        gl.glStencilFunc(gl.GL_ALWAYS, 1, 0xFF);
        gl.glStencilOp(gl.GL_KEEP, gl.GL_KEEP, gl.GL_REPLACE);
        gl.glStencilMask(0xFF);
        gl.glColorMask(gl.GL_FALSE, gl.GL_FALSE, gl.GL_FALSE, gl.GL_FALSE);
        gl.glDepthMask(gl.GL_FALSE);

        const mvp_normal = model_mat.mul(vp);
        shader.setUniform("u_mvp", mvp_normal);
        model.vao.draw();

        // Pass 2: Render scaled-up model where stencil != 1
        gl.glStencilFunc(gl.GL_NOTEQUAL, 1, 0xFF);
        gl.glStencilMask(0x00);
        gl.glColorMask(gl.GL_TRUE, gl.GL_TRUE, gl.GL_TRUE, gl.GL_TRUE);
        gl.glDepthMask(gl.GL_FALSE);
        gl.glDisable(gl.GL_DEPTH_TEST);

        const scale_mat = math.Mat4.createScale(scale_factor, scale_factor, scale_factor);
        const scaled_model_mat = scale_mat.mul(model_mat);
        const mvp_scaled = scaled_model_mat.mul(vp);
        shader.setUniform("u_mvp", mvp_scaled);
        model.vao.draw();

        // Restore GL state
        gl.glStencilMask(0xFF);
        gl.glStencilFunc(gl.GL_ALWAYS, 0, 0xFF);
        gl.glEnable(gl.GL_DEPTH_TEST);
        gl.glDepthFunc(gl.GL_LESS);
        gl.glDepthMask(gl.GL_TRUE);
        gl.glDisable(gl.GL_STENCIL_TEST);
    }
};
