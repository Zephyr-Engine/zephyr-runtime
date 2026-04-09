const std = @import("std");

const c = @import("../../c.zig");
const gl = c.glad;
const IndexFormat = @import("zimp").mesh.IndexFormat;

pub const BufferError = error{
    BufferCreationFailed,
    OpenGLError,
};

pub const VertexBuffer = struct {
    id: u32,

    pub fn init(data: []const u8) BufferError!VertexBuffer {
        var vbo = VertexBuffer{ .id = 0 };

        gl.glGenBuffers(1, &vbo.id);
        if (vbo.id == 0) {
            return BufferError.BufferCreationFailed;
        }

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo.id);
        gl.glBufferData(
            gl.GL_ARRAY_BUFFER,
            @intCast(data.len),
            data.ptr,
            gl.GL_STATIC_DRAW,
        );

        const err = gl.glGetError();
        if (err != gl.GL_NO_ERROR) {
            gl.glDeleteBuffers(1, &vbo.id);
            return BufferError.OpenGLError;
        }

        return vbo;
    }

    pub fn initFromSlice(comptime T: type, data: []const T) BufferError!VertexBuffer {
        return init(std.mem.sliceAsBytes(data));
    }

    pub fn bind(self: VertexBuffer) void {
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.id);
    }

    pub fn unbind(self: VertexBuffer) void {
        _ = self;
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0);
    }

    pub fn deinit(self: *VertexBuffer) void {
        gl.glDeleteBuffers(1, &self.id);
        self.id = 0;
    }
};

pub const IndexBuffer = struct {
    id: u32,
    count: usize,
    index_format: IndexFormat,

    pub fn initU32(indices: []const u32) BufferError!IndexBuffer {
        return initRaw(
            std.mem.sliceAsBytes(indices),
            indices.len,
            IndexFormat.u32,
        );
    }

    pub fn initU16(indices: []const u16) BufferError!IndexBuffer {
        return initRaw(
            std.mem.sliceAsBytes(indices),
            indices.len,
            IndexFormat.u16,
        );
    }

    fn initRaw(data: []const u8, count: usize, index_format: IndexFormat) BufferError!IndexBuffer {
        var ebo = IndexBuffer{ .id = 0, .count = count, .index_format = index_format };

        gl.glGenBuffers(1, &ebo.id);
        if (ebo.id == 0) {
            return BufferError.BufferCreationFailed;
        }

        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ebo.id);
        gl.glBufferData(
            gl.GL_ELEMENT_ARRAY_BUFFER,
            @intCast(data.len),
            data.ptr,
            gl.GL_STATIC_DRAW,
        );
        const err = gl.glGetError();
        if (err != gl.GL_NO_ERROR) {
            gl.glDeleteBuffers(1, &ebo.id);
            return BufferError.OpenGLError;
        }

        return ebo;
    }

    pub fn bind(self: *const IndexBuffer) void {
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.id);
    }

    pub fn unbind(_: *const IndexBuffer) void {
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0);
    }

    pub fn deinit(self: *IndexBuffer) void {
        gl.glDeleteBuffers(1, &self.id);
        self.id = 0;
    }
};
