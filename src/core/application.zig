const std = @import("std");

const Framebuffer = @import("../graphics/opengl/framebuffer.zig").Framebuffer;
const Renderer = @import("../graphics/renderer.zig").Renderer;
const Project = @import("../project/project.zig").Project;
const Game = @import("game.zig").Game;
const Runtime = @import("runtime.zig").Runtime;
const event = @import("event.zig");
const Input = @import("input.zig").Input;
const log = @import("log.zig");
const Window = @import("window.zig").Window;
const WindowParams = @import("window.zig").WindowParams;

pub fn Application(comptime game: Game) type {
    const GameRuntime = Runtime(game);

    return struct {
        events: std.ArrayList(event.ZEvent) = .empty,
        runtime: *GameRuntime,
        window: *Window,

        pub fn init(
            allocator: std.mem.Allocator,
            io: std.Io,
            params: WindowParams,
            project: *const Project,
        ) !*@This() {
            const app = try allocator.create(@This());
            errdefer allocator.destroy(app);

            const window = try Window.init(allocator, params);
            errdefer window.deinit(allocator);

            const runtime = try GameRuntime.init(allocator, io, project);
            errdefer runtime.deinit();

            app.* = .{
                .window = window,
                .runtime = runtime,
            };
            window.setEventCallback(app, eventCallback);

            return app;
        }

        pub fn start(self: *@This()) !void {
            try self.runtime.start();
        }

        pub fn run(self: *@This()) !void {
            try self.start();
            while (self.window.shouldCloseWindow()) {
                self.beginFrame();
                self.processQueuedEvents();
                try self.update();
                try self.renderScene(null);
                self.present();
            }
            Window.HandleInput();
        }

        pub fn eventCallback(self: *@This(), ev: event.ZEvent) !void {
            self.events.append(self.runtime.allocator, ev) catch |err| {
                log.err("dropping window events because the event queue cannot grow: {}", .{err});
            };
        }

        pub fn beginFrame(self: *@This()) []const event.ZEvent {
            self.events.clearRetainingCapacity();
            self.runtime.beginFrame(Window.GetTime(), self.window.isFocused());
            Window.HandleInput();
            return self.events.items;
        }

        pub fn processQueuedEvents(self: *@This()) void {
            self.runtime.processEvents(self.events.items);
        }

        pub fn processEvent(self: *@This(), ev: event.ZEvent) void {
            self.runtime.processEvent(ev);
        }

        pub fn input(self: *@This()) *Input {
            return self.runtime.input();
        }

        pub fn update(self: *@This()) !void {
            try self.runtime.update();
        }

        pub fn pumpAssets(self: *@This()) !void {
            try self.runtime.pumpAssets();
        }

        pub fn renderScene(self: *@This(), framebuffer: ?*Framebuffer) !void {
            const target: Renderer.RenderTarget = if (framebuffer) |value|
                .{ .framebuffer = value }
            else blk: {
                const size = self.window.getFramebufferSize();
                break :blk .{ .default_framebuffer = .{ .width = size.width, .height = size.height } };
            };
            try self.runtime.render(target, Window.GetTime());
        }

        pub fn setDebugStatsEnabled(self: *@This(), enabled: bool) void {
            self.runtime.setDebugStatsEnabled(enabled);
        }

        pub fn debugStatsEnabled(self: *const @This()) bool {
            return self.runtime.debugStatsEnabled();
        }

        pub fn debugStats(self: *const @This()) ?Renderer.DebugStats {
            return self.runtime.debugStats();
        }

        pub fn deltaTime(self: *const @This()) f32 {
            return self.runtime.deltaTime();
        }

        pub fn present(self: *@This()) void {
            self.window.swapBuffers();
        }

        pub fn deinit(self: *@This()) void {
            const allocator = self.runtime.allocator;
            self.events.deinit(allocator);
            self.runtime.deinit();
            self.window.deinit(allocator);
            allocator.destroy(self);
        }
    };
}
