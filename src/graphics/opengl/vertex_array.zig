const std = @import("std");

const StreamAttribute = @import("../layout.zig").StreamAttribute;
const IndexFormat = @import("zimp").mesh.IndexFormat;
const buffer = @import("buffer.zig");
const c = @import("../../c.zig");
const gl = c.glad;

const VertexArray = @This();

pub const VertexArrayError = error{
    VertexArrayCreationFailed,
    VertexBufferCreationFailed,
    IndexBufferCreationFailed,
    TooManyStreams,
    OpenGLError,
};

const MAX_STREAMS = 8;

id: u32,
streams: [MAX_STREAMS]?Stream,
stream_count: u32,
ebo: ?buffer.IndexBuffer = null,

const Stream = struct {
    vbo: buffer.VertexBuffer,
    attribute: StreamAttribute,
};

pub fn init() VertexArrayError!VertexArray {
    var vao: u32 = 0;

    gl.glGenVertexArrays(1, &vao);
    if (vao == 0) {
        return VertexArrayError.VertexArrayCreationFailed;
    }
    return .{
        .id = vao,
        .streams = [_]?Stream{null} ** MAX_STREAMS,
        .stream_count = 0,
        .ebo = null,
    };
}

pub fn addStream(
    self: *VertexArray,
    data: []const u8,
    attribute: StreamAttribute,
) VertexArrayError!void {
    if (self.stream_count >= MAX_STREAMS) {
        return VertexArrayError.TooManyStreams;
    }
    gl.glBindVertexArray(self.id);

    const vbo = buffer.VertexBuffer.init(data) catch {
        return VertexArrayError.VertexBufferCreationFailed;
    };

    vbo.bind();

    const loc = attribute.location;
    const dt = attribute.data_type;

    gl.glEnableVertexAttribArray(loc);

    if (dt.isIntegerType()) {
        gl.glVertexAttribIPointer(
            loc,
            @intCast(dt.componentCount()),
            dt.glType(),
            @intCast(dt.size()),
            null,
        );
    } else {
        gl.glVertexAttribPointer(
            loc,
            @intCast(dt.componentCount()),
            dt.glType(),
            if (attribute.normalized) gl.GL_TRUE else gl.GL_FALSE,
            @intCast(dt.size()),
            null,
        );
    }

    self.streams[self.stream_count] = .{
        .vbo = vbo,
        .attribute = attribute,
    };
    self.stream_count += 1;

    gl.glBindVertexArray(0);
}

pub fn setIndexBuffer(self: *VertexArray, ebo: buffer.IndexBuffer) void {
    gl.glBindVertexArray(self.id);
    ebo.bind();
    gl.glBindVertexArray(0);
    self.ebo = ebo;
}

pub fn bind(self: *const VertexArray) void {
    gl.glBindVertexArray(self.id);
}

pub fn unbind(self: *const VertexArray) void {
    _ = self;
    gl.glBindVertexArray(0);
}

pub fn indexCount(self: *const VertexArray) usize {
    const ebo = self.ebo orelse return 0;
    return ebo.count;
}

pub fn drawRange(self: *const VertexArray, first_index: u32, index_count: u32) void {
    const ebo = self.ebo orelse return;

    std.debug.assert(@as(usize, first_index) + @as(usize, index_count) <= ebo.count);

    const gl_type: gl.GLenum = switch (ebo.index_format) {
        .u16 => gl.GL_UNSIGNED_SHORT,
        .u32 => gl.GL_UNSIGNED_INT,
    };

    const byte_offset = indexByteOffset(ebo.index_format, first_index);
    const offset: ?*const anyopaque =
        if (byte_offset == 0) null else @ptrFromInt(byte_offset);

    self.bind();
    gl.glDrawElements(
        gl.GL_TRIANGLES,
        @intCast(index_count),
        gl_type,
        offset,
    );
}

pub fn draw(self: *const VertexArray) void {
    const ebo = self.ebo orelse return;
    self.drawRange(0, @intCast(ebo.count));
}

pub fn deinit(self: *VertexArray) void {
    for (&self.streams) |*stream| {
        if (stream.*) |*s| {
            s.vbo.deinit();
            stream.* = null;
        }
    }

    if (self.ebo) |*ebo| {
        ebo.deinit();
        self.ebo = null;
    }
    gl.glDeleteVertexArrays(1, &self.id);
    self.id = 0;
}

fn indexByteOffset(format: IndexFormat, first_index: u32) usize {
    const index_size: usize = switch (format) {
        .u16 => @sizeOf(u16),
        .u32 => @sizeOf(u32),
    };

    return @as(usize, first_index) * index_size;
}

test "indexCount reports zero without an index buffer and its stored count otherwise" {
    var vertex_array = VertexArray{
        .id = 0,
        .streams = [_]?VertexArray.Stream{null} ** VertexArray.MAX_STREAMS,
        .stream_count = 0,
    };
    try std.testing.expectEqual(@as(usize, 0), vertex_array.indexCount());

    vertex_array.ebo = .{ .id = 0, .count = 36, .index_format = .u32 };
    try std.testing.expectEqual(@as(usize, 36), vertex_array.indexCount());
}

test "index byte offsets account for index format" {
    try std.testing.expectEqual(
        @as(usize, 12),
        indexByteOffset(.u16, 6),
    );

    try std.testing.expectEqual(
        @as(usize, 24),
        indexByteOffset(.u32, 6),
    );
}
