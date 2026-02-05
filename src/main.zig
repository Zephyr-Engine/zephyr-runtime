const std = @import("std");
const zp = @import("zephyr_runtime");

pub const std_options = zp.recommended_std_options;

pub fn main() void {
    zp.run();
}
