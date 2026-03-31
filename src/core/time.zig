const std = @import("std");

pub const Time = struct {
    delta_time: f32,
    last_frame: f32,

    pub fn init() Time {
        return Time{
            .delta_time = 0.0,
            .last_frame = 0.0,
        };
    }

    pub fn update(self: *Time, current_time: f32) void {
        self.delta_time = current_time - self.last_frame;
        self.last_frame = current_time;
    }
};

test "Time initialization" {
    const time = Time.init();
    try std.testing.expectEqual(@as(f32, 0.0), time.delta_time);
    try std.testing.expectEqual(@as(f32, 0.0), time.last_frame);
}

test "Time first update" {
    var time = Time.init();
    time.update(0.016);

    try std.testing.expectApproxEqAbs(@as(f32, 0.016), time.delta_time, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.016), time.last_frame, 0.0001);
}

test "Time successive updates" {
    var time = Time.init();

    time.update(0.016);
    try std.testing.expectApproxEqAbs(@as(f32, 0.016), time.delta_time, 0.0001);

    time.update(0.033);
    try std.testing.expectApproxEqAbs(@as(f32, 0.017), time.delta_time, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.033), time.last_frame, 0.0001);

    time.update(0.050);
    try std.testing.expectApproxEqAbs(@as(f32, 0.017), time.delta_time, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.050), time.last_frame, 0.0001);
}

test "Time large delta" {
    var time = Time.init();
    time.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), time.delta_time, 0.0001);

    time.update(5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), time.delta_time, 0.0001);
}

test "Time zero delta between identical frames" {
    var time = Time.init();
    time.update(1.0);
    time.update(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), time.delta_time, 0.0001);
}
