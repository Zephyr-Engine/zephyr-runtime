const c = @import("../c.zig");
const gl = c.glad;

pub const BufferError = error{
    BufferCreationFailed,
    OpenGLError,
};

pub const VertexBuffer = struct {
    id: u32,

    pub fn init(vertices: []const f32) BufferError!VertexBuffer {
        var vbo = VertexBuffer{ .id = 0 };
        gl.glGenBuffers(1, &vbo.id);

        if (vbo.id == 0) {
            return BufferError.BufferCreationFailed;
        }

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo.id);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(@sizeOf(f32) * vertices.len), vertices.ptr, gl.GL_STATIC_DRAW);

        const err = gl.glGetError();
        if (err != gl.GL_NO_ERROR) {
            gl.glDeleteBuffers(1, &vbo.id);
            return BufferError.OpenGLError;
        }

        return vbo;
    }

    pub fn bind(self: VertexBuffer) void {
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.id);
    }

    pub fn unbind() void {
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
    }
};

pub const IndexBuffer = struct {
    id: u32,
    count: usize,

    pub fn init(vertices: []const u32) BufferError!IndexBuffer {
        var ebo = IndexBuffer{ .id = 0, .count = vertices.len };
        gl.glGenBuffers(1, &ebo.id);

        if (ebo.id == 0) {
            return BufferError.BufferCreationFailed;
        }

        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ebo.id);
        gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u32) * vertices.len), vertices.ptr, gl.GL_STATIC_DRAW);

        const err = gl.glGetError();
        if (err != gl.GL_NO_ERROR) {
            gl.glDeleteBuffers(1, &ebo.id);
            return BufferError.OpenGLError;
        }

        return ebo;
    }

    pub fn bind(self: IndexBuffer) void {
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.id);
    }

    pub fn unbind() void {
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0);
    }
};
