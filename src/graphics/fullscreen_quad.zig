const c = @import("../c.zig");
const gl = c.glad;

var vao: u32 = 0;
var vbo: u32 = 0;

const quad_vertices = [_]f32{
    // positions   // texcoords
    -1.0, 1.0,  0.0, 1.0,
    -1.0, -1.0, 0.0, 0.0,
    1.0,  -1.0, 1.0, 0.0,

    -1.0, 1.0,  0.0, 1.0,
    1.0,  -1.0, 1.0, 0.0,
    1.0,  1.0,  1.0, 1.0,
};

pub fn ensureInitialized() void {
    if (vao != 0) return;

    gl.glGenVertexArrays(1, &vao);
    gl.glGenBuffers(1, &vbo);
    gl.glBindVertexArray(vao);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo);
    gl.glBufferData(
        gl.GL_ARRAY_BUFFER,
        @intCast(@sizeOf(f32) * quad_vertices.len),
        &quad_vertices,
        gl.GL_STATIC_DRAW,
    );
    // position: vec2 at location 0
    gl.glEnableVertexAttribArray(0);
    gl.glVertexAttribPointer(0, 2, gl.GL_FLOAT, gl.GL_FALSE, 4 * @sizeOf(f32), @ptrFromInt(0));
    // texcoord: vec2 at location 1
    gl.glEnableVertexAttribArray(1);
    gl.glVertexAttribPointer(1, 2, gl.GL_FLOAT, gl.GL_FALSE, 4 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
    gl.glBindVertexArray(0);
}

pub fn draw() void {
    ensureInitialized();
    gl.glBindVertexArray(vao);
    gl.glDrawArrays(gl.GL_TRIANGLES, 0, 6);
    gl.glBindVertexArray(0);
}

pub fn deinit() void {
    if (vbo != 0) {
        gl.glDeleteBuffers(1, &vbo);
        vbo = 0;
    }
    if (vao != 0) {
        gl.glDeleteVertexArrays(1, &vao);
        vao = 0;
    }
}
