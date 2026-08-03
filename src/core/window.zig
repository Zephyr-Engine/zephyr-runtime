const builtin = @import("builtin");
const std = @import("std");

const Backend = @import("../graphics/device_factory.zig").Backend;
const graphics_context = @import("../graphics/context.zig");
const event = @import("event.zig");
const log = @import("log.zig");
const c = @import("../c.zig");
const glfw = c.glfw;

const macos = if (builtin.os.tag == .macos) @cImport({
    @cInclude("objc/message.h");
    @cInclude("objc/runtime.h");
}) else struct {};

extern fn glfwGetCocoaWindow(window: c.Window) ?*anyopaque;

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
    backend: Backend = .opengl,
};

pub const CursorKind = enum {
    arrow,
    hand,
    text,
    resize_x,
    resize_y,
};

const DefaultWindowBounds = struct {
    x: c_int = 0,
    y: c_int = 0,
    width: u32 = 1280,
    height: u32 = 720,
};

fn getDefaultWindowBounds() DefaultWindowBounds {
    const monitor = glfw.glfwGetPrimaryMonitor() orelse return .{};

    var x: c_int = 0;
    var y: c_int = 0;
    var width: c_int = 0;
    var height: c_int = 0;
    glfw.glfwGetMonitorWorkarea(monitor, &x, &y, &width, &height);
    if (width > 0 and height > 0) {
        return .{
            .x = x,
            .y = y,
            .width = @intCast(width),
            .height = @intCast(height),
        };
    }

    const video = glfw.glfwGetVideoMode(monitor) orelse return .{};
    return .{
        .width = @intCast(video.*.width),
        .height = @intCast(video.*.height),
    };
}

const Window = @This();

window: c.Window,
data: WindowData,
event_fn: ?*const fn (*anyopaque, event.ZEvent) anyerror!void = null,
event_ctx: *anyopaque = undefined,
arrow_cursor: ?*glfw.GLFWcursor = null,
hand_cursor: ?*glfw.GLFWcursor = null,
text_cursor: ?*glfw.GLFWcursor = null,
resize_x_cursor: ?*glfw.GLFWcursor = null,
resize_y_cursor: ?*glfw.GLFWcursor = null,

pub fn init(allocator: std.mem.Allocator, params: WindowParams) WindowError!*Window {
    if (glfw.glfwInit() == 0) {
        log.err("failed to initialize GLFW", .{});
        return WindowError.InitializeFailed;
    }
    errdefer glfw.glfwTerminate();

    glfw.glfwDefaultWindowHints();
    graphics_context.configure(params.backend, params.msaa_samples);

    const title = allocator.dupeZ(u8, params.title) catch |err| {
        log.err("failed to allocate window title: {}", .{err});
        return WindowError.MemoryError;
    };
    defer allocator.free(title);

    const maximize = params.width == null and params.height == null;
    if (maximize) {
        glfw.glfwWindowHint(glfw.GLFW_MAXIMIZED, glfw.GLFW_TRUE);
    }

    const default_bounds = if (maximize) DefaultWindowBounds{} else getDefaultWindowBounds();
    const width = params.width orelse default_bounds.width;
    const height = params.height orelse default_bounds.height;

    const window = glfw.glfwCreateWindow(@intCast(width), @intCast(height), title, null, null);
    if (window == null) {
        log.err("failed to create GLFW window", .{});
        return WindowError.InitializeFailed;
    }
    errdefer glfw.glfwDestroyWindow(window);
    if (!maximize and (params.width == null or params.height == null)) {
        glfw.glfwSetWindowPos(window, default_bounds.x, default_bounds.y);
    }
    applyPlatformWindowAppearance(window);

    graphics_context.initialize(params.backend, window, params.msaa_samples) catch {
        log.err("failed to load OpenGL functions", .{});
        return WindowError.ContextLoadFailed;
    };

    const win = allocator.create(Window) catch |err| {
        log.err("failed to allocate window state: {}", .{err});
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
    const event_fn = self.event_fn orelse return;
    event_fn(self.event_ctx, ev) catch |err| {
        log.err("failed to dispatch window event: {}", .{err});
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

pub fn isFocused(self: *const Window) bool {
    return glfw.glfwGetWindowAttrib(self.window, glfw.GLFW_FOCUSED) == glfw.GLFW_TRUE;
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

fn applyPlatformWindowAppearance(window: c.Window) void {
    if (builtin.os.tag == .macos) {
        applyMacWindowAppearance(window);
    }
}

fn applyMacWindowAppearance(window: c.Window) void {
    const ns_window = glfwGetCocoaWindow(window) orelse return;

    const ns_string_class = macos.objc_getClass("NSString");
    const ns_appearance_class = macos.objc_getClass("NSAppearance");
    const dark_aqua_name = objcMsgSendId(
        ns_string_class,
        macos.sel_registerName("stringWithUTF8String:"),
        "NSAppearanceNameDarkAqua",
    ) orelse return;
    const dark_appearance = objcMsgSendId(
        ns_appearance_class,
        macos.sel_registerName("appearanceNamed:"),
        dark_aqua_name,
    ) orelse return;

    objcMsgSendVoid(
        ns_window,
        macos.sel_registerName("setAppearance:"),
        dark_appearance,
    );
}

fn objcMsgSendId(receiver: anytype, selector: anytype, argument: anytype) ?*anyopaque {
    const Fn = *const fn (@TypeOf(receiver), @TypeOf(selector), @TypeOf(argument)) callconv(.c) ?*anyopaque;
    const msg_send: Fn = @ptrCast(&macos.objc_msgSend);
    return msg_send(receiver, selector, argument);
}

fn objcMsgSendVoid(receiver: anytype, selector: anytype, argument: anytype) void {
    const Fn = *const fn (@TypeOf(receiver), @TypeOf(selector), @TypeOf(argument)) callconv(.c) void;
    const msg_send: Fn = @ptrCast(&macos.objc_msgSend);
    msg_send(receiver, selector, argument);
}
