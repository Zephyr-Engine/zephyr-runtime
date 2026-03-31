const std = @import("std");
const c = @import("../../c.zig");
const gl = c.glad;
const buffer = @import("buffer.zig");

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
            std.log.err("Failed to create Vertex Buffer: {}", .{err});
            return VertexArrayError.VertexBufferCreationFailed;
        };
        errdefer gl.glDeleteBuffers(1, &vbo.id);

        const ebo = buffer.IndexBuffer.init(indices) catch |err| {
            std.log.err("Failed to create Index Buffer: {}", .{err});
            return VertexArrayError.IndexBufferCreationFailed;
        };
        errdefer gl.glDeleteBuffers(1, &ebo.id);

        const err = gl.glGetError();
        if (err != gl.GL_NO_ERROR) {
            return VertexArrayError.OpenGLError;
        }

        return .{
            .id = vao,
            .vbo = vbo,
            .ebo = ebo,
        };
    }

    pub fn bind(self: *const VertexArray) void {
        gl.glBindVertexArray(self.id);
    }

    pub fn unbind(self: *const VertexArray) void {
        _ = self;
        gl.glBindVertexArray(0);
    }

    pub fn indexCount(self: VertexArray) usize {
        return self.ebo.count;
    }

    pub fn setLayout(self: *const VertexArray) void {
        self.bind();
        gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), @ptrFromInt(0));
        gl.glEnableVertexAttribArray(0);
        self.unbind();
    }

    pub fn draw(self: *const VertexArray) void {
        self.bind();
        gl.glDrawElements(gl.GL_TRIANGLES, 6, gl.GL_UNSIGNED_INT, @ptrFromInt(0));
        self.unbind();
    }
};
