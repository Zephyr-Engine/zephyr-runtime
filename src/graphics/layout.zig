const gl = @import("../c.zig").glad;

pub const StreamAttribute = struct {
    location: u32,
    data_type: DataType,
    normalized: bool,
};

pub const DataType = enum {
    Float,
    Float2,
    Float3,
    Float4,
    Mat3,
    Mat4,
    Int,
    Int2,
    Int3,
    Int4,
    Bool,
    Short2,
    UShort2,
    UShort4,
    Half4,

    pub fn size(dt: DataType) u32 {
        return switch (dt) {
            .Float => 4,
            .Float2 => 8,
            .Float3 => 12,
            .Float4 => 16,
            .Mat3 => 36,
            .Mat4 => 64,
            .Int => 4,
            .Int2 => 8,
            .Int3 => 12,
            .Int4 => 16,
            .Bool => 1,
            .Short2 => 4,
            .UShort2 => 4,
            .UShort4 => 8,
            .Half4 => 8,
        };
    }

    pub fn componentCount(dt: DataType) u32 {
        return switch (dt) {
            .Float => 1,
            .Float2 => 2,
            .Float3 => 3,
            .Float4 => 4,
            .Mat3 => 9,
            .Mat4 => 16,
            .Int => 1,
            .Int2 => 2,
            .Int3 => 3,
            .Int4 => 4,
            .Bool => 1,
            .Short2 => 2,
            .UShort2 => 2,
            .UShort4 => 4,
            .Half4 => 4,
        };
    }

    pub fn glType(dt: DataType) u32 {
        return switch (dt) {
            .Float, .Float2, .Float3, .Float4, .Mat3, .Mat4 => gl.GL_FLOAT,
            .Int, .Int2, .Int3, .Int4 => gl.GL_INT,
            .Bool => gl.GL_BOOL,
            .Short2 => gl.GL_SHORT,
            .UShort2, .UShort4 => gl.GL_UNSIGNED_SHORT,
            .Half4 => gl.GL_HALF_FLOAT,
        };
    }

    pub fn isIntegerType(dt: DataType) bool {
        return switch (dt) {
            .UShort4, .Int, .Int2, .Int3, .Int4 => true,
            else => false,
        };
    }
};
