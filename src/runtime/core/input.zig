const std = @import("std");

const WindowData = @import("window.zig").WindowData;
const event = @import("event.zig");
const c = @import("../c.zig");
const glfw = c.glfw;

pub const InputManager = struct {};

pub fn mouseButtonCallback(window: c.Window, btn: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = mods;

    if (action != glfw.GLFW_PRESS) {
        return;
    }

    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    var ev: event.ZEvent = undefined;
    if (btn == glfw.GLFW_MOUSE_BUTTON_LEFT) {
        ev = event.ZEvent{ .MousePressed = .Left };
        windowData.eventCallback(ev);
    } else if (btn == glfw.GLFW_MOUSE_BUTTON_RIGHT) {
        ev = event.ZEvent{ .MousePressed = .Right };
        windowData.eventCallback(ev);
    }
}

pub fn keyButtonCallback(window: c.Window, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = mods;
    _ = scancode;

    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    var ev: event.ZEvent = undefined;
    if (action == glfw.GLFW_PRESS) {
        ev = event.ZEvent{ .KeyPressed = key };
    } else if (action == glfw.GLFW_REPEAT) {
        ev = event.ZEvent{ .KeyRepeated = key };
    } else if (action == glfw.GLFW_RELEASE) {
        ev = event.ZEvent{ .KeyReleased = key };
    }

    windowData.eventCallback(ev);
}

pub fn windowResizeCallback(window: c.Window, width: c_int, height: c_int) callconv(.c) void {
    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    windowData.*.height = @intCast(height);
    windowData.*.width = @intCast(width);

    const ev = event.ZEvent{ .WindowResize = .{
        .height = @intCast(height),
        .width = @intCast(width),
    } };
    windowData.eventCallback(ev);
}

pub fn windowCloseCallback(window: c.Window) callconv(.c) void {
    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    const ev: event.ZEvent = .WindowClose;
    windowData.eventCallback(ev);
}

pub fn cursorPosCallback(window: c.Window, x: f64, y: f64) callconv(.c) void {
    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    const ev = event.ZEvent{ .MouseMove = .{ .x = x, .y = y } };
    windowData.eventCallback(ev);
}

pub fn cursorScrollCallback(window: c.Window, x: f64, y: f64) callconv(.c) void {
    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    const ev = event.ZEvent{ .MouseScroll = .{ .x = x, .y = y } };
    windowData.eventCallback(ev);
}
