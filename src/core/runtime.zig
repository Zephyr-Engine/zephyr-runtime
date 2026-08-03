const std = @import("std");
const zcs = @import("zcs");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const SchemaRegistry = @import("../scene/schema_registry.zig");
const engine_components = @import("../ecs/components.zig");
const SceneController = @import("../scene/controller.zig");
const DebugStats = @import("../graphics/debug_stats.zig");
const Renderer = @import("../graphics/renderer.zig");
const Project = @import("../project/project.zig");
const ecs = @import("../ecs/world.zig");
const Input = @import("input.zig");
const event = @import("event.zig");
const Game = @import("game.zig");
const Time = @import("time.zig");

pub fn Runtime(comptime game: Game) type {
    return struct {
        command_buffer: zcs.CommandBuffer,
        scenes: SceneController = .{},
        allocator: std.mem.Allocator,
        frame_cpu_start: f64 = 0,
        project: *const Project,
        schemas: SchemaRegistry,
        assets: AssetManager,
        time: Time = .init(),
        renderer: Renderer,
        world: zcs.World,
        io: std.Io,

        pub fn init(allocator: std.mem.Allocator, io: std.Io, project: *const Project) !*@This() {
            const runtime = try allocator.create(@This());
            errdefer allocator.destroy(runtime);

            runtime.* = .{
                .allocator = allocator,
                .io = io,
                .project = project,
                .command_buffer = undefined,
                .schemas = undefined,
                .assets = undefined,
                .renderer = undefined,
                .world = undefined,
            };

            runtime.assets = try AssetManager.init(allocator, io, project);
            errdefer runtime.assets.deinit();

            runtime.schemas = SchemaRegistry.init(allocator);
            errdefer runtime.schemas.deinit();

            runtime.world = .init(allocator);
            errdefer runtime.world.deinit();

            try initializeWorld(game, &runtime.world, &runtime.schemas);
            runtime.command_buffer = .init(&runtime.world);
            errdefer runtime.command_buffer.deinit();

            try runtime.world.setResource(Input, .{});

            runtime.renderer = try Renderer.init(allocator);
            errdefer runtime.renderer.deinit();

            return runtime;
        }

        pub fn start(self: *@This()) !void {
            try self.scenes.startDefault(
                self.allocator,
                self.io,
                self.project,
                &self.world,
                &self.schemas,
                &self.assets,
            );
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
            try zcs.Schedule.tickDt(
                &self.world,
                &self.command_buffer,
                self.time.delta_time,
                game.update_schedule,
            );
        }

        pub fn render(self: *@This(), target: Renderer.RenderTarget) !void {
            try self.renderer.render(&self.world, &self.assets, target);
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
            self.renderer.deinit();
            self.command_buffer.deinit();
            self.scenes.deinit(&self.world);
            self.world.deinit();
            self.schemas.deinit();
            self.assets.deinit();
            self.allocator.destroy(self);
        }
    };
}

fn initializeWorld(comptime game: Game, world: *zcs.World, schemas: *SchemaRegistry) !void {
    try ecs.registerEngineComponents(world);
    inline for (game.components) |Component| {
        const name = if (@hasDecl(Component, "schema_meta")) Component.schema_meta.name else @typeName(Component);
        _ = try ecs.registerComponent(world, Component, name);
    }

    try schemas.registerComponents(&.{
        engine_components.TransformComponent,
        engine_components.MeshRenderComponent,
        engine_components.CameraComponent,
    });
    try schemas.registerComponents(game.components);
}

test "runtime bootstrap registers engine components and schemas" {
    var world = zcs.World.init(std.testing.allocator);
    defer world.deinit();
    var schemas = SchemaRegistry.init(std.testing.allocator);
    defer schemas.deinit();

    try initializeWorld(.{ .components = &.{}, .update_schedule = .{} }, &world, &schemas);

    try std.testing.expect(world.componentId(engine_components.TransformComponent) != null);
    try std.testing.expect(schemas.getByName(engine_components.TransformComponent.schema_meta.name) != null);
}
