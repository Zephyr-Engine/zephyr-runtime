const std = @import("std");
const c = @import("c.zig");
const win = @import("core/window.zig");
const Shader = @import("graphics/opengl_shader.zig").Shader;
const va = @import("graphics/opengl_vertex_array.zig");
const glfw = c.glfw;
const gl = c.glad;

pub fn run() void {
    var window = win.Window.init().?;
    window.setupCallbacks();
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

    const vao = va.VertexArray.init(&vertices, &indices);
    const vs_src =
        \\#version 330 core
        \\
        \\layout(location = 0) in vec3 aPos;
        \\
        \\void main() {
        \\    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
        \\}
    ;

    const fs_src =
        \\#version 330 core
        \\
        \\out vec4 FragColor;
        \\
        \\void main() {
        \\    FragColor = vec4(0.8f, 0.2f, 0.2f, 1.0f);
        \\}
    ;

    const shader = Shader.init(vs_src, fs_src);
    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), @ptrFromInt(0));
    gl.glEnableVertexAttribArray(0);

    gl.glViewport(0, 0, 1920, 1080);
    while (window.shouldCloseWindow()) {
        window.handleInput();

        gl.glClearColor(0.4, 0.4, 0.4, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        shader.bind();
        vao.bind();
        gl.glDrawElements(gl.GL_TRIANGLES, @intCast(vao.indexCount()), gl.GL_UNSIGNED_INT, @ptrFromInt(0));
        vao.unbind();

        window.swapBuffers();
    }

    glfw.glfwPollEvents();
}
