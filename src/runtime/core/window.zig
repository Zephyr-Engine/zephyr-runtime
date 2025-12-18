const std = @import("std");
const c = @import("../c.zig");
const glfw = c.glfw;

pub const Window = struct {
    window: c.Window,

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

        return .{
            .window = window,
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
