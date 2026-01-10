const std = @import("std");

const Application = @import("application.zig").Application;
const input = @import("input.zig");
const event = @import("event.zig");
const c = @import("../c.zig");
const glfw = c.glfw;
const gl = c.glad;

pub const WindowData = struct {
    width: u32,
    height: u32,
    eventCallback: event.ZEventCallback,
    app_ptr: ?*Application,
};

pub const WindowParams = struct {
    width: ?u32,
    height: ?u32,
    title: []const u8,
};

pub fn getDefaultWidth() u32 {
    const monitor = glfw.glfwGetPrimaryMonitor();
    const video_mode = glfw.glfwGetVideoMode(monitor);
    const full_width: u32 = @intCast(video_mode.*.width);
    return @intFromFloat(@as(f32, @floatFromInt(full_width)) * 0.5);
}

pub fn getDefaultHeight() u32 {
    const monitor = glfw.glfwGetPrimaryMonitor();
    const video_mode = glfw.glfwGetVideoMode(monitor);
    const full_height: u32 = @intCast(video_mode.*.height);
    return @intFromFloat(@as(f32, @floatFromInt(full_height)) * 0.5);
}

pub const Window = struct {
    window: c.Window,
    data: WindowData,

    fn setupCallbacks(self: *Window) void {
        glfw.glfwSetWindowUserPointer(self.window, &self.data);
        _ = glfw.glfwSetMouseButtonCallback(self.window, event.mouseButtonCallback);
        _ = glfw.glfwSetKeyCallback(self.window, event.keyButtonCallback);
        _ = glfw.glfwSetWindowSizeCallback(self.window, event.windowResizeCallback);
        _ = glfw.glfwSetFramebufferSizeCallback(self.window, event.framebufferSizeCallback);
        _ = glfw.glfwSetWindowCloseCallback(self.window, event.windowCloseCallback);
        _ = glfw.glfwSetCursorPosCallback(self.window, event.cursorPosCallback);
        _ = glfw.glfwSetScrollCallback(self.window, event.cursorScrollCallback);
    }

    pub fn init(allocator: std.mem.Allocator, params: WindowParams) !?*Window {
        if (glfw.glfwInit() == 0) {
            std.log.err("Failed to initialize glfw", .{});
            return null;
        }
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
        glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

        const title = allocator.dupeZ(u8, params.title) catch {
            std.log.err("Failed to duplicate window title", .{});
            glfw.glfwTerminate();
            return null;
        };
        defer allocator.free(title);

        const width = if (params.width) |w| w else getDefaultWidth();
        const height = if (params.height) |h| h else getDefaultHeight();

        const window = glfw.glfwCreateWindow(@intCast(width), @intCast(height), title, null, null);
        if (window == null) {
            std.log.err("Failed to initialize glfw window", .{});
            return null;
        }

        glfw.glfwMakeContextCurrent(window);
        glfw.glfwSwapInterval(1); // vsync

        const loader: gl.GLADloadproc = @ptrCast(&glfw.glfwGetProcAddress);
        if (gl.gladLoadGLLoader(loader) == 0) {
            std.log.err("Failed to load OpenGL", .{});
            return null;
        }

        const win = try allocator.create(Window);
        win.* = Window{
            .window = window,
            .data = WindowData{
                .width = width,
                .height = height,
                .eventCallback = undefined,
                .app_ptr = null,
            },
        };
        win.setupCallbacks();

        var fb_width: c_int = undefined;
        var fb_height: c_int = undefined;
        glfw.glfwGetFramebufferSize(window, &fb_width, &fb_height);
        gl.glViewport(0, 0, @intCast(fb_width), @intCast(fb_height));

        return win;
    }

    pub fn setWireframeMode(self: *Window) void {
        _ = self;
        gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE);
    }

    pub fn setVsync(self: *Window, value: bool) void {
        _ = self;
        glfw.glfwSwapInterval(value);
    }

    pub fn setEventCallback(self: *Window, cb: event.ZEventCallback, app: *Application) void {
        self.*.data.eventCallback = cb;
        self.*.data.app_ptr = app;
    }

    pub fn shouldCloseWindow(self: *Window) bool {
        return glfw.glfwWindowShouldClose(self.window) == 0;
    }

    pub fn handleInput(self: *Window) void {
        _ = self;
        glfw.glfwPollEvents();
    }

    pub fn GetTime() f64 {
        return glfw.glfwGetTime();
    }

    pub fn swapBuffers(self: *Window) void {
        glfw.glfwSwapBuffers(self.window);
    }

    pub fn deinit(self: *Window, allocator: std.mem.Allocator) void {
        glfw.glfwTerminate();
        glfw.glfwDestroyWindow(self.window);
        allocator.destroy(self);
    }
};
