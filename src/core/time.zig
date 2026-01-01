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

test "Time update calculates delta correctly" {
    var time = Time.init();

    time.update(1.0);
    try std.testing.expectEqual(@as(f32, 1.0), time.delta_time);
    try std.testing.expectEqual(@as(f32, 1.0), time.last_frame);

    time.update(1.5);
    try std.testing.expectEqual(@as(f32, 0.5), time.delta_time);
    try std.testing.expectEqual(@as(f32, 1.5), time.last_frame);

    time.update(2.0);
    try std.testing.expectEqual(@as(f32, 0.5), time.delta_time);
    try std.testing.expectEqual(@as(f32, 2.0), time.last_frame);
}

test "Time update handles non-sequential times" {
    var time = Time.init();

    time.update(5.0);
    try std.testing.expectEqual(@as(f32, 5.0), time.delta_time);
    try std.testing.expectEqual(@as(f32, 5.0), time.last_frame);

    time.update(3.0);
    try std.testing.expectEqual(@as(f32, -2.0), time.delta_time);
    try std.testing.expectEqual(@as(f32, 3.0), time.last_frame);
}
