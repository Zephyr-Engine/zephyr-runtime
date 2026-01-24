const c = @import("../c.zig");
const gl = c.glad;
const buffer = @import("opengl_buffer.zig");
const BufferLayout = @import("layout.zig").BufferLayout;
const ShaderType = @import("layout.zig").DataType;

pub const VertexArrayError = error{
    VertexArrayCreationFailed,
    VertexBufferCreationFailed,
    IndexBufferCreationFailed,
    OpenGLError,
};

pub const VertexArray = struct {
    id: u32,
    vbo: buffer.VertexBuffer,
    ebo: buffer.IndexBuffer,

    pub fn init(vertices: []const f32, indices: []const u32) VertexArrayError!VertexArray {
        var vao: u32 = 0;
        gl.glGenVertexArrays(1, &vao);

        if (vao == 0) {
            return VertexArrayError.VertexArrayCreationFailed;
        }
        errdefer gl.glDeleteVertexArrays(1, &vao);

        gl.glBindVertexArray(vao);

        const vbo = buffer.VertexBuffer.init(vertices) catch |err| {
            return switch (err) {
                buffer.BufferError.BufferCreationFailed, buffer.BufferError.OpenGLError => VertexArrayError.VertexBufferCreationFailed,
            };
        };
        errdefer gl.glDeleteBuffers(1, &vbo.id);

        const ebo = buffer.IndexBuffer.init(indices) catch |err| {
            gl.glDeleteBuffers(1, &vbo.id);
            return switch (err) {
                buffer.BufferError.BufferCreationFailed, buffer.BufferError.OpenGLError => VertexArrayError.IndexBufferCreationFailed,
            };
        };

        const gl_err = gl.glGetError();
        if (gl_err != gl.GL_NO_ERROR) {
            gl.glDeleteBuffers(1, &vbo.id);
            gl.glDeleteBuffers(1, &ebo.id);
            return VertexArrayError.OpenGLError;
        }

        return .{
            .id = vao,
            .vbo = vbo,
            .ebo = ebo,
        };
    }

    pub fn bind(self: VertexArray) void {
        gl.glBindVertexArray(self.id);
    }

    pub fn unbind(self: VertexArray) void {
        _ = self;
        gl.glBindVertexArray(0);
    }

    pub fn indexCount(self: VertexArray) usize {
        return self.ebo.count;
    }

    pub fn setLayout(self: VertexArray, layout: BufferLayout) VertexArrayError!void {
        self.bind();
        for (layout.elements.items) |element| {
            gl.glVertexAttribPointer(element.location, @intCast(element.ty.componentCount()), layoutTypeToGL(element.ty), if (element.normalized) 1 else 0, @intCast(layout.stride), @ptrFromInt(element.offset));
            gl.glEnableVertexAttribArray(element.location);

            const err = gl.glGetError();
            if (err != gl.GL_NO_ERROR) {
                self.unbind();
                return VertexArrayError.OpenGLError;
            }
        }
        self.unbind();
    }

    pub fn draw(self: VertexArray) void {
        self.bind();
        gl.glDrawElements(gl.GL_TRIANGLES, @intCast(self.indexCount()), gl.GL_UNSIGNED_INT, @ptrFromInt(0));
        self.unbind();
    }
};

fn layoutTypeToGL(ty: ShaderType) c_uint {
    return switch (ty) {
        .Float => gl.GL_FLOAT,
        .Float2 => gl.GL_FLOAT,
        .Float3 => gl.GL_FLOAT,
        .Float4 => gl.GL_FLOAT,
        .Int => gl.GL_INT,
        .Int2 => gl.GL_INT,
        .Int3 => gl.GL_INT,
        .Int4 => gl.GL_INT,
        .Bool => gl.GL_BOOL,
        .Mat3 => gl.GL_FLOAT,
        .Mat4 => gl.GL_FLOAT,
    };
}
