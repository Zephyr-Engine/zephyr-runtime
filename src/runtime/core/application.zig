const std = @import("std");
const c = @import("../c.zig");
const win = @import("window.zig");
const event = @import("event.zig");
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const va = @import("../graphics/opengl_vertex_array.zig");
const glfw = c.glfw;
const gl = c.glad;

pub const Application = struct {
    window: *win.Window,

    pub fn init(allocator: std.mem.Allocator) !*Application {
        const window = try win.Window.init(allocator);
        if (window == null) {
            std.log.err("Window creation failed", .{});
        }

        window.?.setEventCallback(Application.eventCallback);

        const app = try allocator.create(Application);
        app.* = Application{
            .window = window.?,
        };

        return app;
    }

    pub fn deinit(self: *Application, allocator: std.mem.Allocator) void {
        self.window.deinit(allocator);
        allocator.destroy(self);
    }

    fn eventCallback(e: event.ZEvent) void {
        switch (e) {
            .MousePressed => |m| {
                switch (m) {
                    .Left => {
                        std.log.info("Left pressed", .{});
                    },
                    .Right => {
                        std.log.info("Right pressed", .{});
                    },
                }
            },
            .MouseReleased => |m| {
                switch (m) {
                    .Left => {
                        std.log.info("Left released", .{});
                    },
                    .Right => {
                        std.log.info("Right released", .{});
                    },
                }
            },
            .KeyPressed => |k| {
                std.log.info("{s} pressed", .{@tagName(k)});
            },
            .WindowResize => |s| {
                std.log.info("Resize w: {d}, h: {d}", .{ s.width, s.height });
            },
            .WindowClose => {
                std.log.info("Shutting down", .{});
            },
            .MouseMove => |p| {
                std.log.info("Mouse x: {}, y: {}", .{ p.x, p.y });
            },
            .MouseScroll => |p| {
                std.log.info("Scroll x: {}, y: {}", .{ p.x, p.y });
            },
            else => return,
        }

        return;
    }

    pub fn run(app: *Application) void {
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
        while (app.window.shouldCloseWindow()) {
            app.window.handleInput();

            gl.glClearColor(0.4, 0.4, 0.4, 1);
            gl.glClear(gl.GL_COLOR_BUFFER_BIT);

            shader.bind();
            vao.bind();
            gl.glDrawElements(gl.GL_TRIANGLES, @intCast(vao.indexCount()), gl.GL_UNSIGNED_INT, @ptrFromInt(0));
            vao.unbind();

            app.window.swapBuffers();
        }

        glfw.glfwPollEvents();
    }
};
