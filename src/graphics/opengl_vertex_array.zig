const c = @import("../c.zig");
const gl = c.glad;
const buffer = @import("opengl_buffer.zig");

pub const VertexArray = struct {
    id: u32,
    vbo: buffer.VertexBuffer,
    ebo: buffer.IndexBuffer,

    pub fn init(vertices: []const f32, indices: []const u32) VertexArray {
        var vao: u32 = 0;
        gl.glGenVertexArrays(1, &vao);
        gl.glBindVertexArray(vao);

        return .{
            .id = vao,
            .vbo = buffer.VertexBuffer.init(vertices),
            .ebo = buffer.IndexBuffer.init(indices),
        };
    }

    pub fn bind(self: VertexArray) void {
        gl.glBindVertexArray(self.id);
    }

    pub fn unbind() void {
        gl.glBindVertexArray(0);
    }

    pub fn indexCount(self: VertexArray) usize {
        return self.ebo.count;
    }
};
