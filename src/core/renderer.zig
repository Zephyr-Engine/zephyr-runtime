const Model = @import("../asset/model.zig").Model;
const Camera = @import("../scene/camera.zig").Camera;
const math = @import("zlm").as(f32);
const c = @import("../c.zig");
const gl = c.glad;

pub const RenderCommand = struct {
    pub fn Draw(model: *Model, camera: *Camera) void {
        const modelMatrix = math.Mat4.createTranslation(model.position);
        model.material.setUniform("r_position", camera.viewProjectionMatrix().mul(modelMatrix));
        model.material.setUniform("r_viewPos", camera.position);

        model.material.setUniform("r_model", modelMatrix);
        model.material.setUniform("material.ambient", model.material.lighting.ambient);
        model.material.setUniform("material.diffuse", model.material.lighting.diffuse);
        model.material.setUniform("material.specular", model.material.lighting.specular);
        model.material.setUniform("material.shininess", model.material.lighting.shininess);
        model.draw();
    }

    pub fn Clear(color: math.Vec3) void {
        gl.glClearColor(color.x, color.y, color.z, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
    }

    pub fn SetViewport(x: i32, y: i32, width: i32, height: i32) void {
        gl.glViewport(x, y, width, height);
    }
};
