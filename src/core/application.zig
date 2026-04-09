const std = @import("std");

const SceneManager = @import("../scene/manager.zig").SceneManager;
const Scene = @import("../scene/scene.zig").Scene;
const Input = @import("input.zig").InputManager;
const Time = @import("time.zig").Time;
const glfw = @import("../c.zig").glfw;
const win = @import("window.zig");
const WindowParams = win.WindowParams;
const Window = win.Window;
const event = @import("event.zig");

pub const ApplicationError = error{
    WindowError,
};

pub const Application = struct {
    scene_manager: *SceneManager,
    window: *Window,
    allocator: std.mem.Allocator,
    time: Time,
    io: std.Io,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, params: WindowParams) !*Application {
        const window = Window.init(allocator, params) catch |err| {
            std.log.err("Failed to initialize window: {}", .{err});
            return ApplicationError.WindowError;
        };

        const app = try allocator.create(Application);
        app.* = Application{
            .scene_manager = try .init(allocator),
            .allocator = allocator,
            .window = window,
            .time = .init(),
            .io = io,
        };
        window.setEventCallback(app, eventCallback);

        return app;
    }

    pub fn run(app: *Application) void {
        app.scene_manager.initScene(app.io) catch |err| {
            std.log.err("Error initializing scene: {}", .{err});
            return;
        };

        while (app.window.shouldCloseWindow()) {
            const current_time = Window.GetTime();
            app.time.update(@floatCast(current_time));

            Window.HandleInput();

            app.scene_manager.updateScene(app.time.delta_time) catch |err| {
                std.log.err("Error updating scene: {}", .{err});
                continue;
            };
            app.window.swapBuffers();

            Input.Clear();
        }

        Window.HandleInput();
    }

    pub fn eventCallback(self: *const Application, ev: event.ZEvent) !void {
        Input.Update(ev);
        try self.scene_manager.handleEvent(ev);
    }

    pub fn deinit(self: *Application) !void {
        try self.scene_manager.deinit();
        self.window.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn pushScene(self: *Application, comptime scene: type, is_active: bool) void {
        self.scene_manager.addScene(scene, is_active) catch |err| {
            std.log.err("Failed to push scene: {}", .{err});
            return;
        };
    }
};
