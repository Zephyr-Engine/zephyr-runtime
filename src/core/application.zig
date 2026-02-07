const std = @import("std");

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

    pub fn init(allocator: std.mem.Allocator, params: WindowParams) !*Application {
        const window = Window.init(allocator, params) catch |err| {
            std.log.err("Failed to initialize window: {}", .{err});
            return ApplicationError.WindowError;
        };

        const app = try allocator.create(Application);
        app.* = Application{
            .allocator = allocator,
            .window = window,
        };
        app.setupCallbacks();

        return app;
    }

    fn setupCallbacks(self: *Application) void {
        glfw.glfwSetWindowUserPointer(self.window.window, self);
        _ = glfw.glfwSetMouseButtonCallback(self.window.window, event.mouseButtonCallback);
        _ = glfw.glfwSetKeyCallback(self.window.window, event.keyButtonCallback);
        _ = glfw.glfwSetCharCallback(self.window.window, event.charCallback);
        _ = glfw.glfwSetWindowSizeCallback(self.window.window, event.windowResizeCallback);
        _ = glfw.glfwSetFramebufferSizeCallback(self.window.window, event.framebufferSizeCallback);
        _ = glfw.glfwSetWindowContentScaleCallback(self.window.window, event.contentScaleCallback);
        _ = glfw.glfwSetWindowCloseCallback(self.window.window, event.windowCloseCallback);
        _ = glfw.glfwSetCursorPosCallback(self.window.window, event.cursorPosCallback);
        _ = glfw.glfwSetScrollCallback(self.window.window, event.cursorScrollCallback);
    }

    pub fn eventCallback(self: *const Application, ev: event.ZEvent) void {
        _ = self;
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
