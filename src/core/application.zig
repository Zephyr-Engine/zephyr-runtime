const std = @import("std");

const SchemaRegistry = @import("../scene/schema_registry.zig").SchemaRegistry;
const Framebuffer = @import("../graphics/opengl/framebuffer.zig").Framebuffer;
const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const RenderViewport = @import("runtime_context.zig").RenderViewport;
const LoadedScene = @import("../scene/loader.zig").LoadedScene;
const Project = @import("../project/project.zig").Project;
const engine_components = @import("../ecs/components.zig");
const debug_stats = @import("../graphics/debug_stats.zig");
const runtime_context = @import("runtime_context.zig");
const renderer = @import("../graphics/renderer.zig");
const ecs = @import("../ecs/world.zig");
const InputManager = input.InputManager;
const WindowParams = win.WindowParams;
const Time = @import("time.zig").Time;
const glfw = @import("../c.zig").glfw;
const InputState = input.InputState;
const input = @import("input.zig");
const event = @import("event.zig");
const win = @import("window.zig");
const log = @import("log.zig");
const Window = win.Window;
const zcs = @import("zcs");

pub const ApplicationError = error{
    WindowError,
};

pub fn Application(comptime Game: type) type {
    comptime if (!@hasDecl(Game, "components")) {
        @compileError("Game must declare `pub const components = &.{ ... }`");
    };
    comptime if (!@hasDecl(Game, "update_schedule")) {
        @compileError("Game must declare `pub const update_schedule = zcs.Schedule.Spec{ ... }`");
    };

    const CommandBuffer = zcs.CommandBuffer;
    const Schedule = zcs.Schedule;
    const RuntimeContext = runtime_context.RuntimeContext;
    const Renderer = renderer.Renderer;

    return struct {
        events: std.ArrayList(event.ZEvent) = .empty,
        schemas: SchemaRegistry,
        assets: AssetManager,
        ctx: RuntimeContext,
        command_buffer: CommandBuffer,
        window: *Window,
        time: Time,
        debug_stats: debug_stats.Collector = .{},
        active_scene: ?LoadedScene,

        pub fn init(
            allocator: std.mem.Allocator,
            io: std.Io,
            params: WindowParams,
            project: *const Project,
        ) !*@This() {
            const window = Window.init(allocator, params) catch |err| {
                log.err("failed to initialize window: {}", .{err});
                return ApplicationError.WindowError;
            };
            errdefer window.deinit(allocator);

            var assets = try AssetManager.init(
                allocator,
                io,
                project,
            );
            errdefer assets.deinit();

            const app = try allocator.create(@This());
            errdefer allocator.destroy(app);
            app.* = @This(){
                .schemas = SchemaRegistry.init(allocator),
                .window = window,
                .time = .init(),
                .ctx = undefined,
                .command_buffer = undefined,
                .active_scene = null,
                .assets = assets,
            };
            errdefer app.schemas.deinit();
            app.ctx = .{
                .allocator = allocator,
                .io = io,
                .assets = &app.assets,
                .schemas = &app.schemas,
                .project = project,
                .world = .init(allocator),
            };

            try ecs.registerEngineComponents(&app.ctx.world);

            inline for (Game.components) |Component| {
                const name = if (@hasDecl(Component, "schema_meta")) Component.schema_meta.name else @typeName(Component);
                const component_id = try ecs.registerComponent(&app.ctx.world, Component, name);
                std.debug.assert(@intFromEnum(component_id) > 3);
            }
            try app.schemas.registerComponents(&.{ engine_components.TransformComponent, engine_components.MeshRenderComponent, engine_components.CameraComponent });
            try app.schemas.registerComponents(Game.components);
            app.command_buffer = .init(&app.ctx.world);
            try app.ctx.world.setResource(InputState, .{});
            window.setEventCallback(app, eventCallback);

            return app;
        }

        pub fn run(app: *@This()) void {
            app.start() catch |err| {
                log.err("failed to initialize scene; terminating application run: {}", .{err});
                return;
            };

            while (app.window.shouldCloseWindow()) {
                _ = app.beginFrame();
                app.processQueuedEvents() catch |err| {
                    log.err("failed to process events; terminating application run: {}", .{err});
                    return;
                };

                app.update() catch |err| {
                    log.err("failed to update application; terminating application run: {}", .{err});
                    return;
                };
                app.present();
            }

            Window.HandleInput();
        }

        pub fn eventCallback(self: *@This(), ev: event.ZEvent) !void {
            self.events.append(self.ctx.allocator, ev) catch |err| {
                log.err("dropping window events because the event queue cannot grow: {}", .{err});
            };
        }

        pub fn start(self: *@This()) !void {
            self.active_scene = try LoadedScene.loadDefaultScene(&self.ctx);
            try self.active_scene.?.start(&self.ctx);
        }

        pub fn beginFrame(self: *@This()) []const event.ZEvent {
            self.events.clearRetainingCapacity();
            self.time.update(@floatCast(Window.GetTime()));
            Window.HandleInput();
            return self.events.items;
        }

        pub fn processQueuedEvents(self: *@This()) !void {
            try self.processEvents(self.events.items);
        }

        pub fn processEvents(self: *@This(), events: []const event.ZEvent) !void {
            for (events) |ev| {
                try self.processEvent(ev);
            }
        }

        pub fn processEvent(self: *@This(), ev: event.ZEvent) !void {
            InputManager.Update(ev);
            self.ctx.world.getResource(InputState).* = InputManager.snapshot();
        }

        pub fn pumpAssets(self: *@This()) !void {
            try self.assets.pump();
        }

        pub fn update(self: *@This()) !void {
            try self.pumpAssets();
            try self.renderScene(null);
        }

        pub fn renderScene(self: *@This(), target: ?*Framebuffer) !void {
            var restore_default = false;
            if (target) |framebuffer| {
                framebuffer.bind();
                self.ctx.render_viewport = .{
                    .width = framebuffer.width,
                    .height = framebuffer.height,
                };
                restore_default = true;
            } else {
                const fb_size = self.window.getFramebufferSize();
                Framebuffer.bindDefault(fb_size.width, fb_size.height);
                self.ctx.render_viewport = .{
                    .width = fb_size.width,
                    .height = fb_size.height,
                };
            }
            defer if (restore_default) {
                const fb_size = self.window.getFramebufferSize();
                Framebuffer.bindDefault(fb_size.width, fb_size.height);
            };

            const cpu_start = Window.GetTime();
            try Schedule.tickDt(
                &self.ctx.world,
                &self.command_buffer,
                self.time.delta_time,
                Game.update_schedule,
            );
            self.debug_stats.beginGpuTimer();
            defer self.debug_stats.endGpuTimer();
            try Renderer.renderWorld(&self.ctx);
            const cpu_elapsed_ms: f32 = @floatCast(@max(0, Window.GetTime() - cpu_start) * 1000);
            self.debug_stats.recordCpuFrame(self.time.delta_time, cpu_elapsed_ms);
        }

        /// Enables or disables runtime render-stat collection for host debug UIs.
        pub fn setDebugStatsEnabled(self: *@This(), enabled: bool) void {
            self.debug_stats.setEnabled(enabled);
        }

        pub fn debugStatsEnabled(self: *const @This()) bool {
            return self.debug_stats.enabled;
        }

        pub fn debugStats(self: *const @This()) ?debug_stats.DebugStats {
            return self.debug_stats.snapshot();
        }

        pub fn present(self: *@This()) void {
            self.window.swapBuffers();
            InputManager.Clear();
            self.ctx.world.getResource(InputState).* = InputManager.snapshot();
        }

        pub fn deinit(self: *@This()) !void {
            self.command_buffer.deinit();
            if (self.active_scene) |*active_scene| {
                active_scene.deinit(&self.ctx.world);
            }
            self.ctx.world.deinit();
            self.events.deinit(self.ctx.allocator);
            self.schemas.deinit();
            self.assets.deinit();
            self.debug_stats.deinit();
            self.window.deinit(self.ctx.allocator);
            self.ctx.allocator.destroy(self);
        }
    };
}
