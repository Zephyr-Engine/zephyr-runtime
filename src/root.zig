const builtin = @import("builtin");
const std = @import("std");

pub const Application = @import("core/application.zig").Application;
pub const recommended_std_options: std.Options = .{
    .log_level = if (builtin.mode == .ReleaseFast) .err else .debug,
    .logFn = @import("core/log.zig").log,
};
