const Model = @import("../asset/model.zig").Model;
const Camera = @import("../scene/camera.zig").Camera;
const math = @import("zlm").as(f32);
const c = @import("../c.zig");
const gl = c.glad;

pub const RenderCommand = struct {
    pub fn Draw(model: *Model, camera: *Camera) void {
        model.material.setUniform("r_position", camera.viewProjectionMatrix().mul(math.Mat4.createTranslation(model.position)));
        model.draw();
    }

    pub fn Clear(color: math.Vec3) void {
        gl.glClearColor(color.x, color.y, color.z, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
    }
};
