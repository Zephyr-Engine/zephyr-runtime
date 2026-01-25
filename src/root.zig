const std = @import("std");
const c = @import("c.zig");
const glfw = c.glfw;
const gl = c.glad;

const Shader = @import("graphics/opengl/shader.zig").Shader;
const VertexArray = @import("graphics/opengl/vertex_array.zig").VertexArray;

pub fn run() !void {
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

    const vertices = [_]f32{
        0.5, 0.5, 0.0, // top right
        0.5, -0.5, 0.0, // bottom right
        -0.5, -0.5, 0.0, // bottom left
        -0.5, 0.5, 0.0, // top left
    };

    const indices = [_]u32{
        0, 1, 3, // first triangle
        1, 2, 3, // second triangle
    };

    const vao = VertexArray.init(&vertices, &indices);

    const vs_src: [*c]const u8 = @embedFile("assets/shaders/vertex.glsl");
    const fs_src: [*c]const u8 = @embedFile("assets/shaders/fragment.glsl");
    const shader = try Shader.init(vs_src, fs_src);

    vao.bind();
    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), @ptrFromInt(0));
    gl.glEnableVertexAttribArray(0);

    while (glfw.glfwWindowShouldClose(window) == 0) {
        glfw.glfwPollEvents();

        gl.glClearColor(0.4, 0.4, 0.4, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        shader.bind();
        vao.bind();
        gl.glDrawElements(gl.GL_TRIANGLES, 6, gl.GL_UNSIGNED_INT, @ptrFromInt(0));

        glfw.glfwSwapBuffers(window);
    }

    glfw.glfwPollEvents();
}
