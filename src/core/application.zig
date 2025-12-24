const std = @import("std");
const c = @import("../c.zig");
const win = @import("window.zig");
const event = @import("event.zig");
const scene = @import("scene.zig");
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const va = @import("../graphics/opengl_vertex_array.zig");
const glfw = c.glfw;
const gl = c.glad;

pub const Application = struct {
    window: *win.Window,
    scene_manager: scene.SceneManager,
    last_frame_time: f64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*Application {
        const window = try win.Window.init(allocator);
        if (window == null) {
            std.log.err("Window creation failed", .{});
        }

        const app = try allocator.create(Application);
        app.* = Application{
            .window = window.?,
            .scene_manager = scene.SceneManager.init(allocator),
            .last_frame_time = glfw.glfwGetTime(),
            .allocator = allocator,
        };

        window.?.setEventCallback(Application.eventCallback, app);

        return app;
    }

    pub fn deinit(self: *Application, allocator: std.mem.Allocator) void {
        self.scene_manager.deinit();
        self.window.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn pushScene(self: *Application, new_scene: scene.Scene) !void {
        try self.scene_manager.pushScene(new_scene);
    }

    pub fn popScene(self: *Application) ?scene.Scene {
        return self.scene_manager.popScene();
    }

    fn eventCallback(self: *Application, e: event.ZEvent) void {
        self.scene_manager.handleEvent(e);
    }

    pub fn run(app: *Application) void {
        while (app.window.shouldCloseWindow()) {
            gl.glViewport(0, 0, @intCast(app.window.data.width), @intCast(app.window.data.height));

            const current_time = glfw.glfwGetTime();
            const delta_time: f32 = @floatCast(current_time - app.last_frame_time);
            app.last_frame_time = current_time;

            gl.glClearColor(0.4, 0.4, 0.4, 1);
            gl.glClear(gl.GL_COLOR_BUFFER_BIT);

            app.window.handleInput();
            app.scene_manager.update(delta_time);

            app.window.swapBuffers();
        }

        glfw.glfwPollEvents();
    }
};
