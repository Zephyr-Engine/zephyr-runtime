const std = @import("std");

const Window = @import("window.zig");
const log = @import("log.zig");
const c = @import("../c.zig");
const glfw = c.glfw;

pub const MouseButton = enum(u8) {
    Left = 0,
    Right = 1,
    Middle = 2,
    Button3 = 3,
    Button4 = 4,
    Button5 = 5,
    Button6 = 6,
    Button7 = 7,
};

pub const Key = enum(u16) {
    Unknown = 0,
    Space = 32,
    Apostrophe = 39,
    Comma = 44,
    Minus = 45,
    Period = 46,
    Slash = 47,
    Num0 = 48,
    Num1 = 49,
    Num2 = 50,
    Num3 = 51,
    Num4 = 52,
    Num5 = 53,
    Num6 = 54,
    Num7 = 55,
    Num8 = 56,
    Num9 = 57,
    Semicolon = 59,
    Equal = 61,
    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,
    LeftBracket = 91,
    Backslash = 92,
    RightBracket = 93,
    GraveAccent = 96,
    World1 = 161,
    World2 = 162,
    Escape = 256,
    Enter = 257,
    Tab = 258,
    Backspace = 259,
    Insert = 260,
    Delete = 261,
    Right = 262,
    Left = 263,
    Down = 264,
    Up = 265,
    PageUp = 266,
    PageDown = 267,
    Home = 268,
    End = 269,
    CapsLock = 280,
    ScrollLock = 281,
    NumLock = 282,
    PrintScreen = 283,
    Pause = 284,
    F1 = 290,
    F2 = 291,
    F3 = 292,
    F4 = 293,
    F5 = 294,
    F6 = 295,
    F7 = 296,
    F8 = 297,
    F9 = 298,
    F10 = 299,
    F11 = 300,
    F12 = 301,
    F13 = 302,
    F14 = 303,
    F15 = 304,
    F16 = 305,
    F17 = 306,
    F18 = 307,
    F19 = 308,
    F20 = 309,
    F21 = 310,
    F22 = 311,
    F23 = 312,
    F24 = 313,
    F25 = 314,
    Kp0 = 320,
    Kp1 = 321,
    Kp2 = 322,
    Kp3 = 323,
    Kp4 = 324,
    Kp5 = 325,
    Kp6 = 326,
    Kp7 = 327,
    Kp8 = 328,
    Kp9 = 329,
    KpDecimal = 330,
    KpDivide = 331,
    KpMultiply = 332,
    KpSubtract = 333,
    KpAdd = 334,
    KpEnter = 335,
    KpEqual = 336,
    LeftShift = 340,
    LeftControl = 341,
    LeftAlt = 342,
    LeftSuper = 343,
    RightShift = 344,
    RightControl = 345,
    RightAlt = 346,
    RightSuper = 347,
    Menu = 348,

    pub fn fromGLFW(key: c_int) Key {
        return @enumFromInt(key);
    }
};

pub const ZEvent = union(enum) {
    WindowClose,
    WindowResize: struct { width: u32, height: u32 },
    FramebufferResize: struct { width: u32, height: u32 },
    ContentScaleChange: struct { x: f32, y: f32 },
    KeyPressed: Key,
    KeyReleased: Key,
    KeyRepeated: Key,
    CharInput: u32, // Unicode codepoint for text input
    MouseScroll: struct { x: f32, y: f32 },
    MouseMove: struct { x: f32, y: f32 },
    MousePressed: MouseButton,
    MouseReleased: MouseButton,
};

inline fn getWindowFromGLFW(window: c.Window) ?*Window {
    const ptr = glfw.glfwGetWindowUserPointer(window) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

pub fn mouseButtonCallback(window: c.Window, btn: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = mods;

    const isPress = action == glfw.GLFW_PRESS;
    const isRelease = action == glfw.GLFW_RELEASE;
    if (!isPress and !isRelease) {
        return;
    }

    if (btn < 0 or btn > 7) {
        return;
    }

    const win = getWindowFromGLFW(window) orelse return;

    const button: MouseButton = @enumFromInt(@as(u8, @intCast(btn)));
    const ev: ZEvent = if (isPress)
        ZEvent{ .MousePressed = button }
    else
        ZEvent{ .MouseReleased = button };

    win.dispatchEvent(ev);
}

pub fn keyButtonCallback(window: c.Window, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = mods;
    _ = scancode;

    const win = getWindowFromGLFW(window) orelse return;
    const mappedKey = Key.fromGLFW(key);
    if (mappedKey == .Unknown) {
        log.debug("ignoring unknown GLFW key code: {}", .{key});
        return;
    }

    const ev: ZEvent = switch (action) {
        glfw.GLFW_PRESS => .{ .KeyPressed = mappedKey },
        glfw.GLFW_REPEAT => .{ .KeyRepeated = mappedKey },
        glfw.GLFW_RELEASE => .{ .KeyReleased = mappedKey },
        else => return,
    };

    win.dispatchEvent(ev);
}

pub fn windowResizeCallback(window: c.Window, width: c_int, height: c_int) callconv(.c) void {
    if (width < 0 or height < 0) return;
    const win = getWindowFromGLFW(window) orelse return;
    win.setSize(@intCast(width), @intCast(height));

    const ev = ZEvent{ .WindowResize = .{
        .height = @intCast(height),
        .width = @intCast(width),
    } };
    win.dispatchEvent(ev);
}

pub fn framebufferSizeCallback(window: c.Window, width: c_int, height: c_int) callconv(.c) void {
    if (width < 0 or height < 0) return;
    const win = getWindowFromGLFW(window) orelse return;

    const ev = ZEvent{ .FramebufferResize = .{
        .width = @intCast(width),
        .height = @intCast(height),
    } };
    win.dispatchEvent(ev);
}

pub fn contentScaleCallback(window: c.Window, xscale: f32, yscale: f32) callconv(.c) void {
    const win = getWindowFromGLFW(window) orelse return;

    const ev = ZEvent{ .ContentScaleChange = .{ .x = xscale, .y = yscale } };
    win.dispatchEvent(ev);
}

pub fn windowCloseCallback(window: c.Window) callconv(.c) void {
    const win = getWindowFromGLFW(window) orelse return;

    const ev: ZEvent = .WindowClose;
    win.dispatchEvent(ev);
}

pub fn cursorPosCallback(window: c.Window, x: f64, y: f64) callconv(.c) void {
    const win = getWindowFromGLFW(window) orelse return;

    const ev = ZEvent{ .MouseMove = .{ .x = @floatCast(x), .y = @floatCast(y) } };
    win.dispatchEvent(ev);
}

pub fn cursorScrollCallback(window: c.Window, x: f64, y: f64) callconv(.c) void {
    const win = getWindowFromGLFW(window) orelse return;

    const ev = ZEvent{ .MouseScroll = .{ .x = @floatCast(x), .y = @floatCast(y) } };
    win.dispatchEvent(ev);
}

pub fn charCallback(window: c.Window, codepoint: c_uint) callconv(.c) void {
    const win = getWindowFromGLFW(window) orelse return;

    const ev = ZEvent{ .CharInput = @intCast(codepoint) };
    win.dispatchEvent(ev);
}

test "Key.fromGLFW maps known and unknown key codes" {
    try std.testing.expectEqual(Key.A, Key.fromGLFW(glfw.GLFW_KEY_A));
    try std.testing.expectEqual(Key.F12, Key.fromGLFW(glfw.GLFW_KEY_F12));
    try std.testing.expectEqual(Key.Unknown, Key.fromGLFW(-1));
    try std.testing.expectEqual(Key.Unknown, Key.fromGLFW(glfw.GLFW_KEY_UNKNOWN));
    try std.testing.expectEqual(Key.Unknown, Key.fromGLFW(31));
}

test "Key values are the GLFW key codes" {
    try std.testing.expectEqual(@intFromEnum(Key.Space), glfw.GLFW_KEY_SPACE);
    try std.testing.expectEqual(@intFromEnum(Key.Apostrophe), glfw.GLFW_KEY_APOSTROPHE);
    try std.testing.expectEqual(@intFromEnum(Key.Num0), glfw.GLFW_KEY_0);
    try std.testing.expectEqual(@intFromEnum(Key.A), glfw.GLFW_KEY_A);
    try std.testing.expectEqual(@intFromEnum(Key.GraveAccent), glfw.GLFW_KEY_GRAVE_ACCENT);
    try std.testing.expectEqual(@intFromEnum(Key.Escape), glfw.GLFW_KEY_ESCAPE);
    try std.testing.expectEqual(@intFromEnum(Key.F1), glfw.GLFW_KEY_F1);
    try std.testing.expectEqual(@intFromEnum(Key.F25), glfw.GLFW_KEY_F25);
    try std.testing.expectEqual(@intFromEnum(Key.Kp0), glfw.GLFW_KEY_KP_0);
    try std.testing.expectEqual(@intFromEnum(Key.KpEqual), glfw.GLFW_KEY_KP_EQUAL);
    try std.testing.expectEqual(@intFromEnum(Key.LeftShift), glfw.GLFW_KEY_LEFT_SHIFT);
    try std.testing.expectEqual(@intFromEnum(Key.Menu), glfw.GLFW_KEY_MENU);

    inline for (@typeInfo(Key).@"enum".fields) |f| {
        const key: Key = @enumFromInt(f.value);
        try std.testing.expectEqual(key, Key.fromGLFW(f.value));
    }
}
