const std = @import("std");

const event = @import("event.zig");
const c = @import("../c.zig");
const glfw = c.glfw;
const gl = c.glad;

pub const WindowError = error{
    InitializeFailed,
    ContextLoadFailed,
    MemoryError,
};

pub const WindowData = struct {
    width: u32,
    height: u32,
};

pub const WindowSize = struct {
    width: u32,
    height: u32,
};

pub const WindowParams = struct {
    width: ?u32,
    height: ?u32,
    title: []const u8,
    msaa_samples: u32 = 4,
};

pub const CursorKind = enum {
    arrow,
    hand,
    text,
    resize_x,
    resize_y,
};

fn getDefaultWidth() u32 {
    const monitor = glfw.glfwGetPrimaryMonitor();
    const video = glfw.glfwGetVideoMode(monitor);
    const full_width: u32 = @intCast(video.*.width);

    return @intFromFloat(@as(f32, @floatFromInt(full_width)) * 0.5);
}

fn getDefaultHeight() u32 {
    const monitor = glfw.glfwGetPrimaryMonitor();
    const video = glfw.glfwGetVideoMode(monitor);
    const full_height: u32 = @intCast(video.*.height);

    return @intFromFloat(@as(f32, @floatFromInt(full_height)) * 0.5);
}

pub const Window = struct {
    window: c.Window,
    data: WindowData,
    event_fn: *const fn (*anyopaque, event.ZEvent) anyerror!void = undefined,
    event_ctx: *anyopaque = undefined,
    arrow_cursor: ?*glfw.GLFWcursor = null,
    hand_cursor: ?*glfw.GLFWcursor = null,
    text_cursor: ?*glfw.GLFWcursor = null,
    resize_x_cursor: ?*glfw.GLFWcursor = null,
    resize_y_cursor: ?*glfw.GLFWcursor = null,

    pub fn init(allocator: std.mem.Allocator, params: WindowParams) WindowError!*Window {
        if (glfw.glfwInit() == 0) {
            std.log.err("Failed to initialize glfw", .{});
            return WindowError.InitializeFailed;
        }
        errdefer glfw.glfwTerminate();

        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
        glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);
        if (params.msaa_samples > 1) {
            glfw.glfwWindowHint(glfw.GLFW_SAMPLES, @intCast(params.msaa_samples));
        }

        const title = allocator.dupeZ(u8, params.title) catch |err| {
            std.log.err("Failed to duplicate window title: {}", .{err});
            return WindowError.MemoryError;
        };
        defer allocator.free(title);

        const width = if (params.width) |w| w else getDefaultWidth();
        const height = if (params.height) |h| h else getDefaultHeight();

        const window = glfw.glfwCreateWindow(@intCast(width), @intCast(height), title, null, null);
        if (window == null) {
            std.log.err("Failed to initialize glfw window", .{});
            return WindowError.InitializeFailed;
        }
        errdefer glfw.glfwDestroyWindow(window);

        glfw.glfwMakeContextCurrent(window);
        Window.SetVsync(true);

        const loader: gl.GLADloadproc = @ptrCast(&glfw.glfwGetProcAddress);
        if (gl.gladLoadGLLoader(loader) == 0) {
            std.log.err("Failed to load glad", .{});
            return WindowError.ContextLoadFailed;
        }
        if (params.msaa_samples > 1) {
            gl.glEnable(gl.GL_MULTISAMPLE);
        }

        const win = allocator.create(Window) catch |err| {
            std.log.err("Failed to allocate Window: {}", .{err});
            return WindowError.MemoryError;
        };

        win.* = Window{
            .window = window,
            .data = WindowData{
                .width = width,
                .height = height,
            },
        };
        win.arrow_cursor = glfw.glfwCreateStandardCursor(glfw.GLFW_ARROW_CURSOR);
        win.hand_cursor = glfw.glfwCreateStandardCursor(glfw.GLFW_HAND_CURSOR);
        win.text_cursor = glfw.glfwCreateStandardCursor(glfw.GLFW_IBEAM_CURSOR);
        win.resize_x_cursor = glfw.glfwCreateStandardCursor(glfw.GLFW_HRESIZE_CURSOR);
        win.resize_y_cursor = glfw.glfwCreateStandardCursor(glfw.GLFW_VRESIZE_CURSOR);

        var fb_width: c_int = undefined;
        var fb_height: c_int = undefined;
        glfw.glfwGetFramebufferSize(window, &fb_width, &fb_height);
        gl.glViewport(0, 0, fb_width, fb_height);

        return win;
    }

    pub fn setEventCallback(self: *Window, context: anytype, comptime callback: fn (@TypeOf(context), event.ZEvent) anyerror!void) void {
        const Ctx = @TypeOf(context);
        self.event_fn = struct {
            fn dispatch(ctx: *anyopaque, ev: event.ZEvent) anyerror!void {
                try callback(@as(Ctx, @ptrCast(@alignCast(ctx))), ev);
            }
        }.dispatch;
        self.event_ctx = @ptrCast(context);

        glfw.glfwSetWindowUserPointer(self.window, @ptrCast(self));
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

    pub fn dispatchEvent(self: *Window, ev: event.ZEvent) void {
        self.event_fn(self.event_ctx, ev) catch |err| {
            std.log.err("Error dispatching event: {}", .{err});
        };
    }

    pub fn setSize(self: *Window, width: u32, height: u32) void {
        self.data.width = width;
        self.data.height = height;
    }

    pub fn getWindowSize(self: *const Window) WindowSize {
        var width: c_int = 0;
        var height: c_int = 0;
        glfw.glfwGetWindowSize(self.window, &width, &height);
        return .{
            .width = @intCast(@max(1, width)),
            .height = @intCast(@max(1, height)),
        };
    }

    pub fn getFramebufferSize(self: *const Window) WindowSize {
        var width: c_int = 0;
        var height: c_int = 0;
        glfw.glfwGetFramebufferSize(self.window, &width, &height);
        return .{
            .width = @intCast(@max(1, width)),
            .height = @intCast(@max(1, height)),
        };
    }

    pub fn getContentScale(self: *const Window) struct { x: f32, y: f32 } {
        var x_scale: f32 = 1;
        var y_scale: f32 = 1;
        glfw.glfwGetWindowContentScale(self.window, &x_scale, &y_scale);
        return .{ .x = x_scale, .y = y_scale };
    }

    pub fn setCursor(self: *Window, cursor: CursorKind) void {
        const handle = switch (cursor) {
            .arrow => self.arrow_cursor,
            .hand => self.hand_cursor,
            .text => self.text_cursor,
            .resize_x => self.resize_x_cursor,
            .resize_y => self.resize_y_cursor,
        };
        glfw.glfwSetCursor(self.window, handle);
    }

    pub fn getProcAddress(name: [*:0]const u8) ?*const anyopaque {
        return @ptrCast(glfw.glfwGetProcAddress(name));
    }

    pub fn GetTime() f64 {
        return glfw.glfwGetTime();
    }

    pub fn SetVsync(value: bool) void {
        glfw.glfwSwapInterval(@intFromBool(value));
    }

    pub fn HandleInput() void {
        glfw.glfwPollEvents();
    }

    pub fn swapBuffers(self: *const Window) void {
        glfw.glfwSwapBuffers(self.window);
    }

    pub fn shouldCloseWindow(self: *const Window) bool {
        return glfw.glfwWindowShouldClose(self.window) == 0;
    }

    pub fn deinit(self: *Window, allocator: std.mem.Allocator) void {
        if (self.arrow_cursor) |cursor| glfw.glfwDestroyCursor(cursor);
        if (self.hand_cursor) |cursor| glfw.glfwDestroyCursor(cursor);
        if (self.text_cursor) |cursor| glfw.glfwDestroyCursor(cursor);
        if (self.resize_x_cursor) |cursor| glfw.glfwDestroyCursor(cursor);
        if (self.resize_y_cursor) |cursor| glfw.glfwDestroyCursor(cursor);
        glfw.glfwDestroyWindow(self.window);
        glfw.glfwTerminate();
        allocator.destroy(self);
    }
};
