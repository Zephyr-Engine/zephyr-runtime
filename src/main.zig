const std = @import("std");
const runtime = @import("zephyr_runtime");

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = runtime.log,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const application = try runtime.Application.init(allocator);
    defer application.deinit(allocator);
    application.run();
}
