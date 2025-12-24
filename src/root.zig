const std = @import("std");
const builtin = @import("builtin");

pub const Application = @import("core/application.zig").Application;
pub const log = @import("core/log.zig").log;

pub const recommended_std_options: std.Options = .{
    .log_level = if (builtin.mode == .ReleaseFast) .err else .debug,
    .logFn = log,
};
