const std = @import("std");
const zcs = @import("zcs");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const engine_components = @import("../ecs/components.zig");
const ecs = @import("../ecs/world.zig");
const Renderer = @import("../graphics/renderer.zig").Renderer;
const Project = @import("../project/project.zig").Project;
const SceneController = @import("../scene/controller.zig").SceneController;
const SchemaRegistry = @import("../scene/schema_registry.zig").SchemaRegistry;
const Game = @import("game.zig").Game;
const Input = @import("input.zig").Input;
const event = @import("event.zig");
const RuntimeContext = @import("runtime_context.zig").RuntimeContext;
const Time = @import("time.zig").Time;

pub fn Runtime(comptime game: Game) type {
    return struct {
        allocator: std.mem.Allocator,
        assets: AssetManager,
        schemas: SchemaRegistry,
        ctx: RuntimeContext,
        command_buffer: zcs.CommandBuffer,
        renderer: Renderer,
        scenes: SceneController = .{},
        time: Time = .init(),
        frame_cpu_start: f64 = 0,

        pub fn init(allocator: std.mem.Allocator, io: std.Io, project: *const Project) !*@This() {
            const runtime = try allocator.create(@This());
            errdefer allocator.destroy(runtime);

            runtime.* = .{
                .allocator = allocator,
                .assets = undefined,
                .schemas = undefined,
                .ctx = undefined,
                .command_buffer = undefined,
                .renderer = undefined,
            };

            runtime.assets = try AssetManager.init(allocator, io, project);
            errdefer runtime.assets.deinit();

            runtime.schemas = SchemaRegistry.init(allocator);
            errdefer runtime.schemas.deinit();

            runtime.ctx = .{
                .allocator = allocator,
                .io = io,
                .assets = &runtime.assets,
                .schemas = &runtime.schemas,
                .project = project,
                .world = .init(allocator),
            };
            errdefer runtime.ctx.world.deinit();

            try initializeWorld(game, &runtime.ctx.world, &runtime.schemas);
            runtime.command_buffer = .init(&runtime.ctx.world);
            errdefer runtime.command_buffer.deinit();
            try runtime.ctx.world.setResource(Input, .{});

            runtime.renderer = try Renderer.init(allocator);
            errdefer runtime.renderer.deinit();
            return runtime;
        }

        pub fn start(self: *@This()) !void {
            try self.scenes.startDefault(&self.ctx);
        }

        pub fn beginFrame(self: *@This(), now: f64, focused: bool) void {
            self.ctx.world.getResource(Input).beginFrame();
            self.ctx.world.getResource(Input).setFocused(focused);
            self.time.update(@floatCast(now));
            self.frame_cpu_start = now;
        }

        pub fn processEvents(self: *@This(), events: []const event.ZEvent) void {
            for (events) |ev| self.processEvent(ev);
        }

        pub fn processEvent(self: *@This(), ev: event.ZEvent) void {
            self.input().applyEvent(ev);
        }

        pub fn input(self: *@This()) *Input {
            return self.ctx.world.getResource(Input);
        }

        pub fn pumpAssets(self: *@This()) !void {
            try self.assets.pump();
        }

        pub fn update(self: *@This()) !void {
            try self.pumpAssets();
            try zcs.Schedule.tickDt(
                &self.ctx.world,
                &self.command_buffer,
                self.time.delta_time,
                game.update_schedule,
            );
        }

        pub fn render(self: *@This(), target: Renderer.RenderTarget, now: f64) !void {
            try self.renderer.render(&self.ctx.world, &self.assets, target);
            const elapsed_ms: f32 = @floatCast(@max(0, now - self.frame_cpu_start) * 1000);
            self.renderer.recordCpuFrame(self.time.delta_time, elapsed_ms);
        }

        pub fn setDebugStatsEnabled(self: *@This(), enabled: bool) void {
            self.renderer.setDebugStatsEnabled(enabled);
        }

        pub fn debugStatsEnabled(self: *const @This()) bool {
            return self.renderer.debugStatsEnabled();
        }

        pub fn debugStats(self: *const @This()) ?Renderer.DebugStats {
            return self.renderer.debugStats();
        }

        pub fn deltaTime(self: *const @This()) f32 {
            return self.time.delta_time;
        }

        pub fn deinit(self: *@This()) void {
            self.renderer.deinit();
            self.command_buffer.deinit();
            self.scenes.deinit(&self.ctx.world);
            self.ctx.world.deinit();
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
