const std = @import("std");

const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const RuntimeContext = @import("runtime_context.zig").RuntimeContext;
const RenderViewport = @import("runtime_context.zig").RenderViewport;
const SceneManager = @import("../scene/manager.zig").SceneManager;
const Framebuffer = @import("../graphics/opengl/framebuffer.zig").Framebuffer;
const AssetRoots = @import("../assets/source.zig").AssetRoots;
const renderer = @import("../graphics/renderer.zig");
const Scene = @import("../scene/scene.zig").Scene;
const Input = @import("input.zig").InputManager;
const Time = @import("time.zig").Time;
const glfw = @import("../c.zig").glfw;
const win = @import("window.zig");
const WindowParams = win.WindowParams;
const Window = win.Window;
const event = @import("event.zig");
const log = @import("log.zig");

pub const ApplicationError = error{
    WindowError,
};

pub const Application = struct {
    scene_manager: *SceneManager,
    window: *Window,
    allocator: std.mem.Allocator,
    time: Time,
    io: std.Io,
    assets: AssetManager,
    ctx: RuntimeContext,
    events: std.ArrayList(event.ZEvent) = .empty,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        params: WindowParams,
        asset_roots: AssetRoots,
    ) !*Application {
        const window = Window.init(allocator, params) catch |err| {
            log.err("failed to initialize window: {}", .{err});
            return ApplicationError.WindowError;
        };
        errdefer window.deinit(allocator);

        var assets = try AssetManager.initFiles(
            allocator,
            io,
            asset_roots,
        );
        errdefer assets.deinit();

        const app = try allocator.create(Application);
        errdefer allocator.destroy(app);
        const scene_manager = try SceneManager.init(allocator);
        errdefer allocator.destroy(scene_manager);
        app.* = Application{
            .scene_manager = scene_manager,
            .allocator = allocator,
            .window = window,
            .time = .init(),
            .io = io,
            .ctx = undefined,
            .assets = assets,
        };
        app.ctx = .{
            .allocator = allocator,
            .io = io,
            .assets = &app.assets,
            .world = .init(allocator),
        };
        window.setEventCallback(app, eventCallback);

        return app;
    }

    pub fn run(app: *Application) void {
        app.start() catch |err| {
            log.err("failed to initialize scene; terminating application run: {}", .{err});
            return;
        };

        while (app.window.shouldCloseWindow()) {
            _ = app.beginFrame();
            app.processQueuedEvents() catch |err| {
                log.err("failed to process events; terminating application run: {}", .{err});
                return;
            };

            app.update() catch |err| {
                log.err("failed to update application; terminating application run: {}", .{err});
                return;
            };
            app.present();
        }

        Window.HandleInput();
    }

    pub fn eventCallback(self: *Application, ev: event.ZEvent) !void {
        self.events.append(self.allocator, ev) catch |err| {
            log.err("dropping window events because the event queue cannot grow: {}", .{err});
        };
    }

    pub fn start(self: *Application) !void {
        try self.scene_manager.initScene(&self.ctx);
    }

    pub fn beginFrame(self: *Application) []const event.ZEvent {
        self.events.clearRetainingCapacity();
        self.time.update(@floatCast(Window.GetTime()));
        Window.HandleInput();
        return self.events.items;
    }

    pub fn processQueuedEvents(self: *Application) !void {
        try self.processEvents(self.events.items);
    }

    pub fn processEvents(self: *Application, events: []const event.ZEvent) !void {
        for (events) |ev| {
            try self.processEvent(ev);
        }
    }

    pub fn processEvent(self: *Application, ev: event.ZEvent) !void {
        Input.Update(ev);
        try self.scene_manager.handleEvent(&self.ctx, ev);
    }

    pub fn pumpAssets(self: *Application) !void {
        try self.assets.pump();
    }

    pub fn update(self: *Application) !void {
        try self.pumpAssets();
        try self.renderScene(null);
    }

    pub fn renderScene(self: *Application, target: ?*Framebuffer) !void {
        var restore_default = false;
        if (target) |framebuffer| {
            framebuffer.bind();
            self.ctx.render_viewport = .{
                .width = framebuffer.width,
                .height = framebuffer.height,
            };
            restore_default = true;
        } else {
            const fb_size = self.window.getFramebufferSize();
            Framebuffer.bindDefault(fb_size.width, fb_size.height);
            self.ctx.render_viewport = .{
                .width = fb_size.width,
                .height = fb_size.height,
            };
        }
        defer if (restore_default) {
            const fb_size = self.window.getFramebufferSize();
            Framebuffer.bindDefault(fb_size.width, fb_size.height);
        };

        self.ctx.world.advanceTick();
        try self.scene_manager.updateScene(&self.ctx, self.time.delta_time);
        try renderer.renderWorld(&self.ctx);
    }

    pub fn present(self: *Application) void {
        self.window.swapBuffers();
        Input.Clear();
    }

    pub fn deinit(self: *Application) !void {
        var shutdown_error: ?anyerror = null;
        self.scene_manager.deinit(&self.ctx) catch |err| {
            shutdown_error = err;
        };
        self.ctx.world.deinit();
        self.events.deinit(self.allocator);
        self.assets.deinit();
        self.window.deinit(self.allocator);
        self.allocator.destroy(self);
        if (shutdown_error) |err| return err;
    }

    pub fn pushScene(self: *Application, comptime scene: type, is_active: bool) void {
        self.scene_manager.addScene(scene, is_active) catch |err| {
            log.err("failed to push scene: {}", .{err});
            return;
        };
    }
};
