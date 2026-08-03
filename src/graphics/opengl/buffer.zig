const diagnostics = @import("diagnostics.zig");
const Buffer = @import("../rhi/buffer.zig");
const gl = @import("../../c.zig").glad;

const OpenGLBuffer = @This();

id: u32,
size: usize,
usage: Buffer.Usage,

pub fn init(desc: Buffer.Desc) !OpenGLBuffer {
    if (desc.initial_data) |bytes| {
        if (bytes.len > desc.size) {
            return error.InitialDataTooLarge;
        }
    }

    var id: u32 = 0;
    gl.glGenBuffers(1, &id);
    if (id == 0) {
        return error.BufferCreationFailed;
    }

    errdefer gl.glDeleteBuffers(1, &id);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, id);

    const initial = desc.initial_data;
    gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(desc.size), if (initial) |bytes| bytes.ptr else null, gl.GL_STATIC_DRAW);
    if (!diagnostics.checkError("creating buffer")) {
        return error.OpenGLError;
    }
    return .{ .id = id, .size = desc.size, .usage = desc.usage };
}

pub fn update(self: *OpenGLBuffer, offset: usize, data: []const u8) !void {
    if (offset > self.size or data.len > self.size - offset) {
        return error.BufferWriteOutOfBounds;
    }

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.id);
    gl.glBufferSubData(gl.GL_ARRAY_BUFFER, @intCast(offset), @intCast(data.len), data.ptr);
    if (!diagnostics.checkError("updating buffer")) {
        return error.OpenGLError;
    }
}

pub fn deinit(self: *OpenGLBuffer) void {
    gl.glDeleteBuffers(1, &self.id);
    self.id = 0;
}
