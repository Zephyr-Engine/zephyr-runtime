const std = @import("std");
const Device = @import("rhi/device.zig");
const DebugStats = @import("debug_stats.zig");

const Collector = @This();
enabled: bool = false,
stats: DebugStats = .{},

pub fn setEnabled(self: *Collector, enabled: bool) void {
    if (self.enabled == enabled) return;
    self.enabled = enabled;
    self.stats = .{};
}
pub fn snapshot(self: *const Collector) ?DebugStats {
    return if (self.enabled) self.stats else null;
}
pub fn recordCpuFrame(self: *Collector, delta_time: f32, elapsed_ms: f32) void {
    if (!self.enabled) return;
    if (std.math.isFinite(delta_time) and delta_time > 0) {
        self.stats.frame_time_ms = delta_time * 1000;
        self.stats.fps = 1 / delta_time;
    } else {
        self.stats.frame_time_ms = 0;
        self.stats.fps = 0;
    }
    self.stats.cpu_time_ms = if (std.math.isFinite(elapsed_ms) and elapsed_ms >= 0) elapsed_ms else 0;
}
pub fn beginGpuTimer(self: *Collector, device: *Device) void {
    if (!self.enabled) return;
    if (device.pollGpuTime()) |ms| self.stats.gpu_time_ms = ms;
    device.beginGpuTimer();
}
pub fn endGpuTimer(self: *Collector, device: *Device) void {
    if (self.enabled) device.endGpuTimer();
}

test "collector validates CPU timings" {
    var c: Collector = .{};
    c.setEnabled(true);
    c.recordCpuFrame(0.02, 3);
    const s = c.snapshot().?;
    try std.testing.expectApproxEqAbs(@as(f32, 50), s.fps, 0.001);
}
