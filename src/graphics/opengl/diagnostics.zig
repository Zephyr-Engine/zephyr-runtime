const std = @import("std");

const log = @import("../../core/log.zig");
const c = @import("../../c.zig");
const gl = c.glad;

pub fn checkError(operation: []const u8) bool {
    var succeeded = true;
    while (true) {
        const err = gl.glGetError();
        if (err == gl.GL_NO_ERROR) {
            return succeeded;
        }

        log.err("OpenGL error while {s}: {s} (0x{x})", .{
            operation,
            errorName(err),
            err,
        });
        succeeded = false;
    }
}

pub fn hasExtension(name: []const u8) bool {
    var extension_count: i32 = 0;
    gl.glGetIntegerv(gl.GL_NUM_EXTENSIONS, &extension_count);
    if (!checkError("enumerating OpenGL extensions")) {
        return false;
    }

    for (0..@intCast(@max(extension_count, 0))) |index| {
        const extension = gl.glGetStringi(gl.GL_EXTENSIONS, @intCast(index)) orelse continue;
        if (std.mem.eql(u8, std.mem.span(extension), name)) {
            return true;
        }
    }
    return false;
}

pub fn errorName(err: u32) []const u8 {
    return switch (err) {
        gl.GL_INVALID_ENUM => "GL_INVALID_ENUM",
        gl.GL_INVALID_VALUE => "GL_INVALID_VALUE",
        gl.GL_INVALID_OPERATION => "GL_INVALID_OPERATION",
        gl.GL_INVALID_FRAMEBUFFER_OPERATION => "GL_INVALID_FRAMEBUFFER_OPERATION",
        gl.GL_OUT_OF_MEMORY => "GL_OUT_OF_MEMORY",
        else => "unknown OpenGL error",
    };
}
