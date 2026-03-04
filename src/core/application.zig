const std = @import("std");

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
    window: *Window,
    allocator: std.mem.Allocator,
    time: Time,

    pub fn init(allocator: std.mem.Allocator, params: WindowParams) !*Application {
        const window = Window.init(allocator, params) catch |err| {
            std.log.err("Failed to initialize window: {}", .{err});
            return ApplicationError.WindowError;
        };

        const app = try allocator.create(Application);
        app.* = Application{
            .allocator = allocator,
            .window = window,
            .time = Time.init(),
        };
        window.setEventCallback(app, eventCallback);

        return app;
    }

    pub fn eventCallback(self: *const Application, ev: event.ZEvent) void {
        _ = self;
        Input.Update(ev);
        switch (ev) {
            .MouseMove => |move_event| {
                std.log.info("MouseMove: x={d}, y={d}", .{ move_event.x, move_event.y });
            },
            .MouseScroll => |scroll_event| {
                std.log.info("MouseScroll: x_offset={d}, y_offset={d}", .{ scroll_event.x, scroll_event.y });
            },
            .KeyPressed => |key| {
                std.log.info("KeyPressed: key={s}", .{@tagName(key)});
            },
            .KeyRepeated => |key| {
                std.log.info("KeyRepeated: key={s}", .{@tagName(key)});
            },
            .KeyReleased => |key| {
                std.log.info("KeyReleased: key={s}", .{@tagName(key)});
            },
            .MousePressed => |button| {
                std.log.info("MousePressed: button={s}", .{@tagName(button)});
            },
            .MouseReleased => |button| {
                std.log.info("MouseReleased: button={s}", .{@tagName(button)});
            },
            else => {
                std.log.info("Event: {s}", .{@tagName(ev)});
            },
        }
    }

    pub fn deinit(self: *Application) void {
        self.window.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};
