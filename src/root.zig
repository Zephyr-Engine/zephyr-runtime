const std = @import("std");
const c = @import("c.zig");
const glfw = c.glfw;
const gl = c.glad;

const Window = @import("core/window.zig").Window;
const Shader = @import("graphics/opengl/shader.zig").Shader;
const VertexArray = @import("graphics/opengl/vertex_array.zig").VertexArray;
const Application = @import("core/application.zig").Application;

pub const recommended_std_options: std.Options = .{
    .logFn = @import("core/log.zig").log,
};

pub fn run() void {
    std.log.info("Starting up application", .{});
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const app = Application.init(allocator, .{
        .title = "Zephyr Engine",
        .width = null,
        .height = null,
    }) catch |err| {
        std.log.err("Application init failed: {}", .{err});
        return;
    };
    defer app.deinit();

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
    const shader = Shader.init(vs_src, fs_src) catch |err| {
        std.log.err("Error creating shader: {}\n", .{err});
        return;
    };

    vao.bind();
    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), @ptrFromInt(0));
    gl.glEnableVertexAttribArray(0);

    while (app.window.shouldCloseWindow()) {
        Window.HandleInput();

        gl.glClearColor(0.4, 0.4, 0.4, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        shader.bind();
        vao.bind();
        gl.glDrawElements(gl.GL_TRIANGLES, 6, gl.GL_UNSIGNED_INT, @ptrFromInt(0));

        app.window.swapBuffers();
    }

    Window.HandleInput();
    std.log.info("Shutting down application", .{});
}
