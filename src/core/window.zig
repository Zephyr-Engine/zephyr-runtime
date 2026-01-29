const std = @import("std");

const Application = @import("application.zig").Application;
const input = @import("input.zig");
const event = @import("event.zig");
const c = @import("../c.zig");
const glfw = c.glfw;
const gl = c.glad;

/// Standard cursor shapes
pub const CursorShape = enum {
    arrow,
    ibeam,
    crosshair,
    hand,
    hresize,
    vresize,
};

/// Opaque cursor handle
pub const Cursor = opaque {};

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
        _ = glfw.glfwSetCharCallback(self.window, event.charCallback);
        _ = glfw.glfwSetWindowSizeCallback(self.window, event.windowResizeCallback);
        _ = glfw.glfwSetFramebufferSizeCallback(self.window, event.framebufferSizeCallback);
        _ = glfw.glfwSetWindowContentScaleCallback(self.window, event.contentScaleCallback);
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
        win.setVsync(true);

        var fb_width: c_int = undefined;
        var fb_height: c_int = undefined;
        glfw.glfwGetFramebufferSize(window, &fb_width, &fb_height);
        gl.glViewport(0, 0, @intCast(fb_width), @intCast(fb_height));

        gl.glEnable(gl.GL_DEPTH_TEST);

        return win;
    }

    pub fn setWireframeMode(self: *Window) void {
        _ = self;
        gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE);
    }

    pub fn setVsync(self: *Window, value: bool) void {
        _ = self;
        glfw.glfwSwapInterval(if (value) 1 else 0);
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

    pub fn getContentScale(self: *Window) struct { x: f32, y: f32 } {
        var xscale: f32 = 1.0;
        var yscale: f32 = 1.0;
        glfw.glfwGetWindowContentScale(self.window, &xscale, &yscale);
        return .{ .x = xscale, .y = yscale };
    }

    pub fn getFramebufferSize(self: *Window) struct { width: u32, height: u32 } {
        var w: c_int = 0;
        var h: c_int = 0;
        glfw.glfwGetFramebufferSize(self.window, &w, &h);
        return .{ .width = @intCast(w), .height = @intCast(h) };
    }

    pub fn swapBuffers(self: *Window) void {
        glfw.glfwSwapBuffers(self.window);
    }

    pub fn deinit(self: *Window, allocator: std.mem.Allocator) void {
        glfw.glfwTerminate();
        glfw.glfwDestroyWindow(self.window);
        allocator.destroy(self);
    }

    /// Set the cursor for this window
    pub fn setCursor(self: *Window, cursor: ?*Cursor) void {
        glfw.glfwSetCursor(self.window, @ptrCast(cursor));
    }

    /// Create a standard cursor
    pub fn createStandardCursor(shape: CursorShape) ?*Cursor {
        const glfw_shape: c_int = switch (shape) {
            .arrow => glfw.GLFW_ARROW_CURSOR,
            .ibeam => glfw.GLFW_IBEAM_CURSOR,
            .crosshair => glfw.GLFW_CROSSHAIR_CURSOR,
            .hand => glfw.GLFW_HAND_CURSOR,
            .hresize => glfw.GLFW_HRESIZE_CURSOR,
            .vresize => glfw.GLFW_VRESIZE_CURSOR,
        };
        return @ptrCast(glfw.glfwCreateStandardCursor(glfw_shape));
    }

    /// Destroy a cursor
    pub fn destroyCursor(cursor: ?*Cursor) void {
        if (cursor) |cur| {
            glfw.glfwDestroyCursor(@ptrCast(cur));
        }
    }

    /// Get the current window context (for use with setCursor when window handle not available)
    pub fn getCurrentContext() ?*Window {
        const ctx = glfw.glfwGetCurrentContext();
        if (ctx == null) return null;
        // Note: This returns a pointer that allows setCursor but not full Window operations
        // since we don't have access to the full Window struct from just the GLFW handle
        return @ptrCast(@alignCast(ctx));
    }

    /// Set cursor on the current context window (convenience for callbacks)
    pub fn setCurrentContextCursor(cursor: ?*Cursor) void {
        const ctx = glfw.glfwGetCurrentContext();
        if (ctx != null) {
            glfw.glfwSetCursor(ctx, @ptrCast(cursor));
        }
    }
};
