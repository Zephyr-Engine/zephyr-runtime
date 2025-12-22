const std = @import("std");
const builtin = @import("builtin");

const Color = struct {
    const red = "\x1b[31m";
    const orange = "\x1b[33m";
    const blue = "\x1b[34m";
    const green = "\x1b[32m";
};

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (comptime builtin.mode == .ReleaseFast) {
        return;
    }

    const color = switch (level) {
        .err => Color.red,
        .warn => Color.orange,
        .info => Color.blue,
        .debug => Color.green,
    };

    const scope_prefix = if (scope == .default) "" else "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    var buffer: [256]u8 = undefined;
    const stderr = std.debug.lockStderrWriter(&buffer);
    defer std.debug.unlockStderrWriter();

    stderr.print(color ++ prefix ++ format ++ Color.reset ++ "\n", args) catch return;
}
