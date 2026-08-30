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

/// Reports and clears errors that were raised before the next OpenGL operation.
///
/// OpenGL keeps errors in a context-wide queue. Call this at API boundaries so a
/// prior caller's error cannot be attributed to, or cause failure of, the next
/// operation.
pub fn clearPendingErrors(operation: []const u8) void {
    _ = checkError(operation);
}

pub fn hasExtension(name: []const u8) bool {
    // Do not let an error from an earlier operation make a supported extension
    // appear unavailable. The caller can use the diagnostic to locate that
    // earlier operation without poisoning capability detection.
    clearPendingErrors("before enumerating OpenGL extensions");

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
    if (!checkError("reading OpenGL extensions")) {
        return false;
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

test "errorName maps known GL error codes" {
    try std.testing.expectEqualStrings("GL_INVALID_ENUM", errorName(gl.GL_INVALID_ENUM));
    try std.testing.expectEqualStrings("GL_INVALID_VALUE", errorName(gl.GL_INVALID_VALUE));
    try std.testing.expectEqualStrings("GL_INVALID_OPERATION", errorName(gl.GL_INVALID_OPERATION));
    try std.testing.expectEqualStrings("GL_INVALID_FRAMEBUFFER_OPERATION", errorName(gl.GL_INVALID_FRAMEBUFFER_OPERATION));
    try std.testing.expectEqualStrings("GL_OUT_OF_MEMORY", errorName(gl.GL_OUT_OF_MEMORY));
}

test "errorName falls back for GL_NO_ERROR and unknown codes" {
    try std.testing.expectEqualStrings("unknown OpenGL error", errorName(gl.GL_NO_ERROR));
    try std.testing.expectEqualStrings("unknown OpenGL error", errorName(0xdead));
}
