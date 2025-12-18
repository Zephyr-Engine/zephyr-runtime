const std = @import("std");
const c = @import("c.zig");
const win = @import("core/window.zig");
const buffer = @import("graphics/opengl_buffer.zig");
const glfw = c.glfw;
const gl = c.glad;

pub fn run() void {
    const window = win.Window.init().?;
    defer window.deinit();

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

    var vao: u32 = 0;
    gl.glGenVertexArrays(1, &vao);
    gl.glBindVertexArray(vao);

    _ = buffer.VertexBuffer.init(&vertices);
    const ebo = buffer.IndexBuffer.init(&indices);

    const vs_src =
        \\#version 330 core
        \\
        \\layout(location = 0) in vec3 aPos;
        \\
        \\void main() {
        \\    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
        \\}
    ;

    const vs_ptrs = [_][*c]const u8{
        @ptrCast(vs_src),
    };

    const vs: u32 = gl.glCreateShader(gl.GL_VERTEX_SHADER);
    gl.glShaderSource(vs, 1, &vs_ptrs, null);
    gl.glCompileShader(vs);

    const fs_src =
        \\#version 330 core
        \\
        \\out vec4 FragColor;
        \\
        \\void main() {
        \\    FragColor = vec4(0.8f, 0.2f, 0.2f, 1.0f);
        \\}
    ;

    const fs_ptrs = [_][*c]const u8{
        @ptrCast(fs_src),
    };

    const fs: u32 = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
    gl.glShaderSource(fs, 1, &fs_ptrs, null);
    gl.glCompileShader(fs);

    const program = gl.glCreateProgram();
    gl.glAttachShader(program, vs);
    gl.glAttachShader(program, fs);
    gl.glLinkProgram(program);

    gl.glDeleteShader(vs);
    gl.glDeleteShader(fs);

    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), @ptrFromInt(0));
    gl.glEnableVertexAttribArray(0);

    while (window.shouldCloseWindow()) {
        window.handleInput();

        gl.glClearColor(0.4, 0.4, 0.4, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        gl.glViewport(0, 0, 1920, 1080);

        gl.glUseProgram(program);
        gl.glBindVertexArray(vao);
        gl.glDrawElements(gl.GL_TRIANGLES, @intCast(ebo.count), gl.GL_UNSIGNED_INT, @ptrFromInt(0));
        gl.glBindVertexArray(0);

        window.swapBuffers();
    }

    glfw.glfwPollEvents();
}
