const std = @import("std");
const c = @import("c.zig");
const glfw = c.glfw;
const gl = c.glad;

pub fn run() void {
    if (glfw.glfwInit() == 0) {
        std.debug.print("Failed to initialize glfw\n", .{});
        return;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    const window = glfw.glfwCreateWindow(1920, 1080, "Zephyr", null, null);
    if (window == null) {
        std.debug.print("Failed to initialize glfw window\n", .{});
        return;
    }
    defer glfw.glfwDestroyWindow(window);

    glfw.glfwMakeContextCurrent(window);
    glfw.glfwSwapInterval(1); // V-SYNC

    const loader: gl.GLADloadproc = @ptrCast(&glfw.glfwGetProcAddress);
    if (gl.gladLoadGLLoader(loader) == 0) {
        std.debug.print("Failed to load glad\n", .{});
        return;
    }

    while (glfw.glfwWindowShouldClose(window) == 0) {
        glfw.glfwPollEvents();

        gl.glClearColor(0.6, 0.4, 0.4, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        glfw.glfwSwapBuffers(window);
    }

    glfw.glfwPollEvents();
}
