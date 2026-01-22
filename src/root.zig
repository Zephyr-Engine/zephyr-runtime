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

    const vertices: [4][3]f32 = .{
        .{ 0.5, 0.5, 0.0 }, // top right
        .{ 0.5, -0.5, 0.0 }, // bottom right
        .{ -0.5, -0.5, 0.0 }, // bottom left
        .{ -0.5, 0.5, 0.0 }, // top left
    };

    const indices: [6]u32 = .{
        0, 1, 3, // first triangle
        1, 2, 3, // second triangle
    };

    var vao: u32 = 0;
    gl.glGenVertexArrays(1, &vao);

    var vbo: u32 = 0;
    gl.glGenBuffers(1, &vbo);

    var ebo: u32 = 0;
    gl.glGenBuffers(1, &ebo);

    const vs_src: [*c]const u8 = @embedFile("assets/shaders/vertex.glsl");
    const vs: u32 = gl.glCreateShader(gl.GL_VERTEX_SHADER);
    gl.glShaderSource(vs, 1, &vs_src, null);
    gl.glCompileShader(vs);

    const fs_src: [*c]const u8 = @embedFile("assets/shaders/fragment.glsl");
    const fs: u32 = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
    gl.glShaderSource(fs, 1, &fs_src, null);
    gl.glCompileShader(fs);

    const program = gl.glCreateProgram();
    gl.glAttachShader(program, vs);
    gl.glAttachShader(program, fs);
    gl.glLinkProgram(program);

    gl.glDeleteShader(vs);
    gl.glDeleteShader(fs);

    gl.glBindVertexArray(vao);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(f32) * 18, &vertices, gl.GL_STATIC_DRAW);

    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ebo);
    gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(f32) * 6, &indices, gl.GL_STATIC_DRAW);

    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), @ptrFromInt(0));
    gl.glEnableVertexAttribArray(0);

    while (glfw.glfwWindowShouldClose(window) == 0) {
        glfw.glfwPollEvents();

        gl.glClearColor(0.4, 0.4, 0.4, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        gl.glUseProgram(program);
        gl.glBindVertexArray(vao);
        gl.glDrawElements(gl.GL_TRIANGLES, 6, gl.GL_UNSIGNED_INT, @ptrFromInt(0));

        glfw.glfwSwapBuffers(window);
    }

    glfw.glfwPollEvents();
}
