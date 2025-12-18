const c = @import("../c.zig");
const gl = c.glad;

pub const VertexBuffer = struct {
    id: u32,

    pub fn init(vertices: []const f32) VertexBuffer {
        var vbo = VertexBuffer{ .id = 0 };
        gl.glGenBuffers(1, &vbo.id);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo.id);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(@sizeOf(f32) * vertices.len), vertices.ptr, gl.GL_STATIC_DRAW);

        return vbo;
    }

    pub fn bind(self: VertexBuffer) void {
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.id);
    }

    pub fn unbind(self: VertexBuffer) void {
        _ = self;
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
    }
};

pub const IndexBuffer = struct {
    id: u32,
    count: u32,

    pub fn init(vertices: []const u32) IndexBuffer {
        var ebo = IndexBuffer{ .id = 0, .count = @intCast(vertices.len) };
        gl.glGenBuffers(1, &ebo.id);

        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ebo.id);
        gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u32) * vertices.len), vertices.ptr, gl.GL_STATIC_DRAW);

        return ebo;
    }

    pub fn bind(self: IndexBuffer) void {
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.id);
    }

    pub fn unbind(self: IndexBuffer) void {
        _ = self;
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0);
    }
};
