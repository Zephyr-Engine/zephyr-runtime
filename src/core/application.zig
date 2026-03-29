const std = @import("std");

const win = @import("window.zig");
const Window = win.Window;
const WindowParams = win.WindowParams;

const event = @import("event.zig");
const scene = @import("scene.zig");
const Time = @import("time.zig").Time;
const Input = @import("input.zig").InputManager;
const Camera = @import("../scene/camera.zig").Camera;
const va = @import("../graphics/opengl_vertex_array.zig");
const RenderCommand = @import("renderer.zig").RenderCommand;
const DrawList = @import("draw_list.zig").DrawList;
const RenderPass = @import("render_pass.zig").RenderPass;
const ShadowMap = @import("shadow_map.zig").ShadowMap;
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const AssetManager = @import("../asset/manager.zig").AssetManager;
const Light = @import("../asset/light.zig").Light;

var isRunning = true;

fn appSceneDrawFn(pass: *RenderPass) void {
    const app: *Application = @ptrCast(@alignCast(pass.user_data orelse return));
    const camera = AssetManager.GetActiveCamera() orelse return;

    app.draw_list.collectFromScene(camera) catch {};
    app.draw_list.sortOpaque();
    app.draw_list.execute(camera);
}

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
    draw_list: DrawList,
    shadow_map: ShadowMap,

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
            .draw_list = DrawList.init(allocator),
            .shadow_map = ShadowMap.init(allocator, 2048, 20.0) catch return ApplicationError.WindowError,
        };
        window.setEventCallback(app, eventCallback);

        const fb = window.getFramebufferSize();
        const width: f32 = @floatFromInt(fb.width);
        const height: f32 = @floatFromInt(fb.height);
        const aspect = width / height;

        _ = try AssetManager.PushCamera(allocator, Camera.new(
            .{ .x = 0, .y = 0, .z = 5 },
            std.math.pi / 4.0,
            aspect,
            0.1,
            100.0,
            true,
        ));

        return app;
    }

    pub fn deinit(self: *Application, allocator: std.mem.Allocator) void {
        self.draw_list.deinit();
        self.shadow_map.deinit();
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

            if (AssetManager.GetActiveCamera()) |_| {
                const lights = AssetManager.GetLights();
                for (lights, 0..) |light, i| {
                    if (light.kind == .directional) {
                        app.shadow_map.shadow_light_index = @intCast(i);
                        app.shadow_map.computeLightSpaceMatrix(light);
                        app.shadow_map.renderShadowPass();
                        break;
                    }
                }

                app.draw_list.setShadowMap(&app.shadow_map);

                const fb = app.window.getFramebufferSize();
                RenderCommand.SetViewport(0, 0, @intCast(fb.width), @intCast(fb.height));

                var scene_pass = RenderPass.init("scene");
                _ = scene_pass
                    .setClearFlags(.{ .color = true, .depth = true, .stencil = true })
                    .setClearColor(0.1, 0.1, 0.15, 1.0)
                    .setDepthTest(true)
                    .setDrawFn(appSceneDrawFn)
                    .setUserData(app);
                scene_pass.execute();
            }

            app.window.swapBuffers();
            Input.Clear();
        }

        win.Window.HandleInput();
    }
};
