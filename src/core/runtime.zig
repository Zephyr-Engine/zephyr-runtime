const std = @import("std");
const zcs = @import("zcs");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const SchemaRegistry = @import("../scene/schema_registry.zig");
const engine_components = @import("../ecs/components.zig");
const DebugStats = @import("../graphics/debug_stats.zig");
const Renderer = @import("../graphics/renderer.zig");
const Project = @import("../project/project.zig");
const WorldInstance = @import("../ecs/world.zig");
const ecs = @import("../ecs/world.zig");
const Input = @import("input.zig");
const event = @import("event.zig");
const Game = @import("game.zig");
const Time = @import("time.zig");

pub fn Runtime(comptime game: Game) type {
    return struct {
        allocator: std.mem.Allocator,
        frame_cpu_start: f64 = 0,
        project: *const Project,
        schemas: SchemaRegistry,
        world: WorldInstance,
        assets: AssetManager,
        time: Time = .init(),
        renderer: Renderer,
        io: std.Io,

        pub fn init(allocator: std.mem.Allocator, io: std.Io, project: *const Project) !*@This() {
            const runtime = try allocator.create(@This());
            errdefer allocator.destroy(runtime);

            runtime.* = .{
                .allocator = allocator,
                .io = io,
                .project = project,
                .schemas = undefined,
                .assets = undefined,
                .renderer = undefined,
                .world = undefined,
            };

            runtime.renderer = try Renderer.init(allocator, .opengl);
            errdefer runtime.renderer.deinit();

            runtime.assets = try AssetManager.init(allocator, io, project, &runtime.renderer.device);
            errdefer runtime.assets.deinit();

            try runtime.assets.preloadBuiltins();

            runtime.schemas = SchemaRegistry.init(allocator);
            errdefer runtime.schemas.deinit();

            try runtime.world.init(allocator, &runtime.schemas, game);
            errdefer runtime.world.deinit();

            try runtime.world.setResource(Input, .{});

            return runtime;
        }

        pub fn start(self: *@This()) !void {
            const default_scene = try self.project.loadDefaultScene(
                self.allocator,
                self.io,
            );

            try self.world.startScene(
                self.allocator,
                &self.assets,
                default_scene,
            );
        }

        pub fn resetActiveScene(self: *@This()) !void {
            try self.world.resetActiveScene();
        }

        pub fn beginFrame(self: *@This(), now: f64, focused: bool) void {
            self.world.getResource(Input).beginFrame();
            self.world.getResource(Input).setFocused(focused);
            self.time.update(@floatCast(now));
            self.frame_cpu_start = now;
        }

        pub fn processEvents(self: *@This(), events: []const event.ZEvent) void {
            for (events) |ev| {
                self.processEvent(ev);
            }
        }

        fn processEvent(self: *@This(), ev: event.ZEvent) void {
            self.input().applyEvent(ev);
        }

        pub fn input(self: *@This()) *Input {
            return self.world.getResource(Input);
        }

        fn pumpAssets(self: *@This()) !void {
            try self.assets.pump();
        }

        pub fn update(self: *@This()) !void {
            try self.pumpAssets();
            try self.tickSchedule(game.update_schedule);
        }

        pub fn updateWithSchedule(self: *@This(), comptime schedule: zcs.Schedule.Spec) !void {
            try self.pumpAssets();
            try self.tickSchedule(schedule);
        }

        pub fn tickSchedule(self: *@This(), comptime schedule: zcs.Schedule.Spec) !void {
            try zcs.Schedule.tickDt(
                &self.world.world,
                &self.world.command_buffer,
                self.time.delta_time,
                schedule,
            );
        }

        pub fn render(self: *@This(), target: Renderer.RenderTarget) !void {
            try self.renderer.render(&self.world.world, &self.assets, target);
        }

        pub fn completeFrame(self: *@This(), now: f64) void {
            const elapsed_ms: f32 = @floatCast(@max(0, now - self.frame_cpu_start) * 1000);
            self.renderer.recordCpuFrame(self.time.delta_time, elapsed_ms);
        }

        pub fn setDebugStatsEnabled(self: *@This(), enabled: bool) void {
            self.renderer.setDebugStatsEnabled(enabled);
        }

        pub fn debugStats(self: *const @This()) ?DebugStats {
            return self.renderer.debugStats();
        }

        pub fn deltaTime(self: *const @This()) f32 {
            return self.time.delta_time;
        }

        pub fn deinit(self: *@This()) void {
            self.assets.deinit();
            self.renderer.deinit();
            self.world.deinit();
            self.schemas.deinit();
            self.allocator.destroy(self);
        }
    };
}
