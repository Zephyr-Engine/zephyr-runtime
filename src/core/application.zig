const std = @import("std");

const c = @import("../c.zig");
const win = @import("window.zig");
const event = @import("event.zig");
const scene = @import("scene.zig");
const input = @import("input.zig");
const Time = @import("time.zig").Time;
const va = @import("../graphics/opengl_vertex_array.zig");
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const glfw = c.glfw;
const gl = c.glad;

pub const Application = struct {
    window: *win.Window,
    scene_manager: scene.SceneManager,
    allocator: std.mem.Allocator,
    time: Time,

    pub fn init(allocator: std.mem.Allocator, params: win.WindowParams) !*Application {
        const window = try win.Window.init(allocator, params);
        if (window == null) {
            std.log.err("Window creation failed", .{});
        }

        const app = try allocator.create(Application);
        app.* = Application{
            .window = window.?,
            .scene_manager = scene.SceneManager.init(allocator),
            .allocator = allocator,
            .time = Time.init(),
        };

        input.Input = input.InputManager.init();
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
        input.Input.update(e);
        self.scene_manager.handleEvent(e);
    }

    pub fn run(app: *Application) void {
        var fb_width: c_int = undefined;
        var fb_height: c_int = undefined;
        glfw.glfwGetFramebufferSize(app.window.window, &fb_width, &fb_height);
        gl.glViewport(0, 0, @intCast(fb_width), @intCast(fb_height));

        while (app.window.shouldCloseWindow()) {
            const current_time = glfw.glfwGetTime();
            app.time.update(@floatCast(current_time));

            gl.glClearColor(0.4, 0.4, 0.4, 1);
            gl.glClear(gl.GL_COLOR_BUFFER_BIT);

            app.window.handleInput();
            app.scene_manager.update(app.time.delta_time);

            app.window.swapBuffers();
            input.Input.clear();
        }

        glfw.glfwPollEvents();
    }
};
