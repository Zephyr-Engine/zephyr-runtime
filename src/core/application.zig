const std = @import("std");

const win = @import("window.zig");
const Window = win.Window;
const WindowParams = win.WindowParams;

const event = @import("event.zig");
const scene = @import("scene.zig");
const Time = @import("time.zig").Time;
const Input = @import("input.zig").InputManager;
const va = @import("../graphics/opengl_vertex_array.zig");
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const AssetManager = @import("../asset/manager.zig").AssetManager;

var isRunning = true;

pub const ApplicationError = error{
    WindowError,
    OutOfMemory,
};

pub const ApplicationProps = struct {
    width: u32,
    height: u32,
    fb_width: u32,
    fb_height: u32,
    content_scale_x: f32,
    content_scale_y: f32,
};

pub const Application = struct {
    window: *win.Window,
    scene_manager: scene.SceneManager,
    allocator: std.mem.Allocator,
    time: Time,

    pub fn init(allocator: std.mem.Allocator, params: WindowParams) ApplicationError!*Application {
        const window = Window.init(allocator, params) catch |err| {
            std.log.err("Failed to initialize window: {}", .{err});
            return ApplicationError.WindowError;
        };

        const app = try allocator.create(Application);
        app.* = Application{
            .window = window,
            .scene_manager = scene.SceneManager.init(allocator),
            .allocator = allocator,
            .time = Time.init(),
        };
        window.setEventCallback(app, eventCallback);

        return app;
    }

    pub fn deinit(self: *Application, allocator: std.mem.Allocator) void {
        AssetManager.Deinit(allocator);
        self.scene_manager.deinit();
        self.window.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn pushScene(self: *Application, new_scene: scene.Scene) void {
        self.scene_manager.pushScene(new_scene);
    }

    pub fn popScene(self: *Application) ?scene.Scene {
        return self.scene_manager.popScene();
    }

    pub fn getProps(self: *Application) ApplicationProps {
        const fb = self.window.getFramebufferSize();
        const scale = self.window.getContentScale();
        return ApplicationProps{
            .width = self.window.data.width,
            .height = self.window.data.height,
            .fb_width = fb.width,
            .fb_height = fb.height,
            .content_scale_x = scale.x,
            .content_scale_y = scale.y,
        };
    }

    pub fn eventCallback(self: *Application, e: event.ZEvent) void {
        Input.Update(e);
        self.scene_manager.handleEvent(e);
    }

    pub fn Shutdown() void {
        isRunning = false;
    }

    pub fn run(app: *Application) void {
        while (app.window.shouldCloseWindow() and isRunning) {
            const current_time = win.Window.GetTime();
            app.time.update(@floatCast(current_time));

            win.Window.HandleInput();

            app.scene_manager.update(app.time.delta_time);

            app.window.swapBuffers();
            Input.Clear();
        }

        win.Window.HandleInput();
    }
};
