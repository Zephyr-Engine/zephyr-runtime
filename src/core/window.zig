const std = @import("std");

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

pub const WindowParams = struct {
    width: ?u32,
    height: ?u32,
    title: []const u8,
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

    pub fn init(allocator: std.mem.Allocator, params: WindowParams) WindowError!*Window {
        if (glfw.glfwInit() == 0) {
            std.log.err("Failed to initialize glfw", .{});
            return WindowError.InitializeFailed;
        }
        errdefer glfw.glfwTerminate();

        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
        glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

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

        var fb_width: c_int = undefined;
        var fb_height: c_int = undefined;
        glfw.glfwGetFramebufferSize(window, &fb_width, &fb_height);
        gl.glViewport(0, 0, fb_width, fb_height);

        return win;
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
        glfw.glfwTerminate();
        glfw.glfwDestroyWindow(self.window);
        allocator.destroy(self);
    }
};
