const VertexArray = @import("../graphics/opengl_vertex_array.zig").VertexArray;
const math = @import("zlm").as(f32);
const c = @import("../c.zig");
const gl = c.glad;

pub const RenderCommand = struct {
    pub fn Draw(vao: VertexArray) void {
        vao.bind();
        gl.glDrawElements(gl.GL_TRIANGLES, @intCast(vao.indexCount()), gl.GL_UNSIGNED_INT, @ptrFromInt(0));
        vao.unbind();
    }

    pub fn Clear(color: math.Vec3) void {
        gl.glClearColor(color.x, color.y, color.z, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
    }
};
