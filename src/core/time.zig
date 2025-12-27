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
