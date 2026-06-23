const std = @import("std");

const c = @import("../c.zig");
const gl = c.glad;

pub const DebugStats = struct {
    fps: f32 = 0,
    frame_time_ms: f32 = 0,
    cpu_time_ms: f32 = 0,
    gpu_time_ms: ?f32 = null,
};

/// Collects the timing data used by a host application's debug overlay.
/// GPU queries are polled without waiting so collecting stats never stalls rendering.
pub const Collector = struct {
    const query_count = 4;

    enabled: bool = false,
    stats: DebugStats = .{},
    query_ids: [query_count]gl.GLuint = [_]gl.GLuint{0} ** query_count,
    query_pending: [query_count]bool = [_]bool{false} ** query_count,
    active_query: ?usize = null,
    queries_initialized: bool = false,

    pub fn setEnabled(self: *Collector, enabled: bool) void {
        if (self.enabled == enabled) return;

        self.enabled = enabled;
        self.stats = .{};
        self.query_pending = [_]bool{false} ** query_count;
        self.active_query = null;
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

    pub fn beginGpuTimer(self: *Collector) void {
        if (!self.enabled) return;
        self.pollGpuTimers();
        self.ensureQueries();

        for (&self.query_pending, 0..) |pending, index| {
            if (pending) continue;
            gl.glBeginQuery(gl.GL_TIME_ELAPSED, self.query_ids[index]);
            self.active_query = index;
            return;
        }
    }

    pub fn endGpuTimer(self: *Collector) void {
        if (self.active_query == null) return;
        gl.glEndQuery(gl.GL_TIME_ELAPSED);
        self.query_pending[self.active_query.?] = true;
        self.active_query = null;
    }

    pub fn deinit(self: *Collector) void {
        if (self.queries_initialized) {
            gl.glDeleteQueries(query_count, &self.query_ids);
        }
        self.* = undefined;
    }

    fn ensureQueries(self: *Collector) void {
        if (self.queries_initialized) return;
        gl.glGenQueries(query_count, &self.query_ids);
        self.queries_initialized = true;
    }

    fn pollGpuTimers(self: *Collector) void {
        if (!self.queries_initialized) return;

        for (&self.query_pending, 0..) |*pending, index| {
            if (!pending.*) continue;

            var available: gl.GLint = 0;
            gl.glGetQueryObjectiv(self.query_ids[index], gl.GL_QUERY_RESULT_AVAILABLE, &available);
            if (available == 0) continue;

            var elapsed_ns: gl.GLuint64 = 0;
            gl.glGetQueryObjectui64v(self.query_ids[index], gl.GL_QUERY_RESULT, &elapsed_ns);
            self.stats.gpu_time_ms = @as(f32, @floatFromInt(elapsed_ns)) / std.time.ns_per_ms;
            pending.* = false;
        }
    }
};

test "collector exposes a snapshot only while enabled" {
    var collector: Collector = .{};
    try std.testing.expect(collector.snapshot() == null);

    collector.setEnabled(true);
    try std.testing.expect(collector.snapshot() != null);

    collector.setEnabled(false);
    try std.testing.expect(collector.snapshot() == null);
}

test "collector converts valid frame timings" {
    var collector: Collector = .{};
    collector.setEnabled(true);
    collector.recordCpuFrame(0.02, 3);

    const stats = collector.snapshot().?;
    try std.testing.expectApproxEqAbs(@as(f32, 50), stats.fps, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20), stats.frame_time_ms, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3), stats.cpu_time_ms, 0.001);
    try std.testing.expect(stats.gpu_time_ms == null);
}

test "collector rejects zero frame deltas" {
    var collector: Collector = .{};
    collector.setEnabled(true);
    collector.recordCpuFrame(0, 0);

    const stats = collector.snapshot().?;
    try std.testing.expectEqual(@as(f32, 0), stats.fps);
    try std.testing.expectEqual(@as(f32, 0), stats.frame_time_ms);
}
