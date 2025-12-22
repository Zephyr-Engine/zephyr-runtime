const std = @import("std");

pub fn bufferedPrint() !void {
    std.debug.print("Zephyr Engine says hello!\n", .{});
}
