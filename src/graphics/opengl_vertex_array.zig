const c = @import("../c.zig");
const gl = c.glad;
const buffer = @import("opengl_buffer.zig");
const BufferLayout = @import("layout.zig").BufferLayout;
const ShaderType = @import("layout.zig").DataType;

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

    pub fn unbind(self: VertexArray) void {
        _ = self;
        gl.glBindVertexArray(0);
    }

    pub fn indexCount(self: VertexArray) usize {
        return self.ebo.count;
    }

    pub fn setLayout(self: VertexArray, layout: BufferLayout) void {
        _ = self;
        for (layout.elements.items) |element| {
            gl.glVertexAttribPointer(element.location, @intCast(element.ty.componentCount()), layoutTypeToGL(element.ty), if (element.normalized) 1 else 0, @intCast(layout.stride), @ptrFromInt(element.offset));
            gl.glEnableVertexAttribArray(element.location);
        }
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
