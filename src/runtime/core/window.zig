const std = @import("std");

const input = @import("input.zig");
const event = @import("event.zig");
const c = @import("../c.zig");
const glfw = c.glfw;
const gl = c.glad;

pub const WindowData = struct {
    width: u32,
    height: u32,
    eventCallback: event.ZEventCallback,
};

fn callback(e: event.ZEvent) void {
    switch (e) {
        .MousePressed => |m| {
            switch (m) {
                .Left => {
                    std.debug.print("Left pressed\n", .{});
                },
                .Right => {
                    std.debug.print("Right pressed\n", .{});
                },
            }
        },
        .KeyPressed => |k| {
            std.debug.print("{c} pressed\n", .{@as(u8, @intCast(k))});
        },
        .WindowResize => |s| {
            std.debug.print("Resize w: {d}, h: {d}\n", .{ s.width, s.height });
        },
        .WindowClose => {
            std.debug.print("Shutting down\n", .{});
        },
        .MouseMove => |p| {
            std.debug.print("Mouse x: {}, y: {}\n", .{ p.x, p.y });
        },
        .MouseScroll => |p| {
            std.debug.print("Scroll x: {}, y: {}\n", .{ p.x, p.y });
        },
        else => return,
    }

    return;
}

pub const Window = struct {
    window: c.Window,
    data: WindowData,

    pub fn setupCallbacks(self: *Window) void {
        glfw.glfwSetWindowUserPointer(self.window, &self.data);
        _ = glfw.glfwSetMouseButtonCallback(self.window, input.mouseButtonCallback);
        _ = glfw.glfwSetKeyCallback(self.window, input.keyButtonCallback);
        _ = glfw.glfwSetWindowSizeCallback(self.window, input.windowResizeCallback);
        _ = glfw.glfwSetWindowCloseCallback(self.window, input.windowCloseCallback);
        _ = glfw.glfwSetCursorPosCallback(self.window, input.cursorPosCallback);
        _ = glfw.glfwSetScrollCallback(self.window, input.cursorScrollCallback);
    }

    pub fn init() ?Window {
        if (glfw.glfwInit() == 0) {
            std.debug.print("Failed to initialize glfw\n", .{});
            return null;
        }

        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
        glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

        const window = glfw.glfwCreateWindow(1920, 1080, "zephyr", null, null);
        if (window == null) {
            std.debug.print("Failed to initialize glfw window\n", .{});
            return null;
        }

        glfw.glfwMakeContextCurrent(window);
        glfw.glfwSwapInterval(1); // vsync

        const loader: gl.GLADloadproc = @ptrCast(&glfw.glfwGetProcAddress);
        if (gl.gladLoadGLLoader(loader) == 0) {
            std.debug.print("Failed to load OpenGL\n", .{});
            return null;
        }

        return .{
            .window = window,
            .data = WindowData{
                .width = 1920,
                .height = 1080,
                .eventCallback = callback,
            },
        };
    }

    pub fn shouldCloseWindow(self: Window) bool {
        return glfw.glfwWindowShouldClose(self.window) == 0;
    }

    pub fn handleInput(self: Window) void {
        _ = self;
        glfw.glfwPollEvents();
    }

    pub fn swapBuffers(self: Window) void {
        glfw.glfwSwapBuffers(self.window);
    }

    pub fn deinit(self: Window) void {
        glfw.glfwTerminate();
        glfw.glfwDestroyWindow(self.window);
    }
};
