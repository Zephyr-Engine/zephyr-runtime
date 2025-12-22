const std = @import("std");
const runtime = @import("zephyr_runtime");

pub fn main() !void {
    try runtime.bufferedPrint();
}
