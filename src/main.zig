const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("zephyr_runtime");

pub const std_options: std.Options = .{
    .log_level = if (builtin.mode == .ReleaseFast) .err else .debug,
    .logFn = if (builtin.mode == .ReleaseFast) noopLog else runtime.log,
};

fn noopLog(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = level;
    _ = scope;
    _ = format;
    _ = args;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const application = try runtime.Application.init(allocator);
    defer application.deinit(allocator);
    application.run();
}
