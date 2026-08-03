const Buffer = @import("buffer.zig");
const ResourceHandle = @import("resource_handle.zig");
const layout = @import("../layout.zig");

pub const IndexFormat = enum { u16, u32 };

pub const VertexStream = struct {
    buffer: Buffer,
    attribute: layout.StreamAttribute,
};

pub const Desc = struct {
    streams: []const VertexStream,
    index_buffer: Buffer,
    index_format: IndexFormat,
    index_count: u32,
};

const Geometry = @This();
handle: ResourceHandle,
index_format: IndexFormat,
index_count: u32,
