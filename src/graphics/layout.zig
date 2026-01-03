const std = @import("std");

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
        };
    }
};

pub const BufferElement = struct {
    normalized: bool,
    offset: u32,
    size: u32,
    ty: DataType,

    pub fn new(ty: DataType, offset: u32, normalized: bool) BufferElement {
        return .{
            .normalized = normalized,
            .offset = offset,
            .ty = ty,
            .size = ty.size(),
        };
    }
};

pub const BufferElements = std.ArrayList(BufferElement);

pub const BufferLayout = struct {
    elements: BufferElements,
    stride: u32,

    pub fn new(elements: BufferElements, stride: u32) BufferLayout {
        return .{
            .elements = elements,
            .stride = stride,
        };
    }
};
