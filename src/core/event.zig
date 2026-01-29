const Application = @import("application.zig").Application;
const WindowData = @import("window.zig").WindowData;
const c = @import("../c.zig");
const glfw = c.glfw;
const gl = c.glad;

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
        return switch (key) {
            glfw.GLFW_KEY_SPACE => .Space,
            glfw.GLFW_KEY_APOSTROPHE => .Apostrophe,
            glfw.GLFW_KEY_COMMA => .Comma,
            glfw.GLFW_KEY_MINUS => .Minus,
            glfw.GLFW_KEY_PERIOD => .Period,
            glfw.GLFW_KEY_SLASH => .Slash,
            glfw.GLFW_KEY_0 => .Num0,
            glfw.GLFW_KEY_1 => .Num1,
            glfw.GLFW_KEY_2 => .Num2,
            glfw.GLFW_KEY_3 => .Num3,
            glfw.GLFW_KEY_4 => .Num4,
            glfw.GLFW_KEY_5 => .Num5,
            glfw.GLFW_KEY_6 => .Num6,
            glfw.GLFW_KEY_7 => .Num7,
            glfw.GLFW_KEY_8 => .Num8,
            glfw.GLFW_KEY_9 => .Num9,
            glfw.GLFW_KEY_SEMICOLON => .Semicolon,
            glfw.GLFW_KEY_EQUAL => .Equal,
            glfw.GLFW_KEY_A => .A,
            glfw.GLFW_KEY_B => .B,
            glfw.GLFW_KEY_C => .C,
            glfw.GLFW_KEY_D => .D,
            glfw.GLFW_KEY_E => .E,
            glfw.GLFW_KEY_F => .F,
            glfw.GLFW_KEY_G => .G,
            glfw.GLFW_KEY_H => .H,
            glfw.GLFW_KEY_I => .I,
            glfw.GLFW_KEY_J => .J,
            glfw.GLFW_KEY_K => .K,
            glfw.GLFW_KEY_L => .L,
            glfw.GLFW_KEY_M => .M,
            glfw.GLFW_KEY_N => .N,
            glfw.GLFW_KEY_O => .O,
            glfw.GLFW_KEY_P => .P,
            glfw.GLFW_KEY_Q => .Q,
            glfw.GLFW_KEY_R => .R,
            glfw.GLFW_KEY_S => .S,
            glfw.GLFW_KEY_T => .T,
            glfw.GLFW_KEY_U => .U,
            glfw.GLFW_KEY_V => .V,
            glfw.GLFW_KEY_W => .W,
            glfw.GLFW_KEY_X => .X,
            glfw.GLFW_KEY_Y => .Y,
            glfw.GLFW_KEY_Z => .Z,
            glfw.GLFW_KEY_LEFT_BRACKET => .LeftBracket,
            glfw.GLFW_KEY_BACKSLASH => .Backslash,
            glfw.GLFW_KEY_RIGHT_BRACKET => .RightBracket,
            glfw.GLFW_KEY_GRAVE_ACCENT => .GraveAccent,
            glfw.GLFW_KEY_WORLD_1 => .World1,
            glfw.GLFW_KEY_WORLD_2 => .World2,
            glfw.GLFW_KEY_ESCAPE => .Escape,
            glfw.GLFW_KEY_ENTER => .Enter,
            glfw.GLFW_KEY_TAB => .Tab,
            glfw.GLFW_KEY_BACKSPACE => .Backspace,
            glfw.GLFW_KEY_INSERT => .Insert,
            glfw.GLFW_KEY_DELETE => .Delete,
            glfw.GLFW_KEY_RIGHT => .Right,
            glfw.GLFW_KEY_LEFT => .Left,
            glfw.GLFW_KEY_DOWN => .Down,
            glfw.GLFW_KEY_UP => .Up,
            glfw.GLFW_KEY_PAGE_UP => .PageUp,
            glfw.GLFW_KEY_PAGE_DOWN => .PageDown,
            glfw.GLFW_KEY_HOME => .Home,
            glfw.GLFW_KEY_END => .End,
            glfw.GLFW_KEY_CAPS_LOCK => .CapsLock,
            glfw.GLFW_KEY_SCROLL_LOCK => .ScrollLock,
            glfw.GLFW_KEY_NUM_LOCK => .NumLock,
            glfw.GLFW_KEY_PRINT_SCREEN => .PrintScreen,
            glfw.GLFW_KEY_PAUSE => .Pause,
            glfw.GLFW_KEY_F1 => .F1,
            glfw.GLFW_KEY_F2 => .F2,
            glfw.GLFW_KEY_F3 => .F3,
            glfw.GLFW_KEY_F4 => .F4,
            glfw.GLFW_KEY_F5 => .F5,
            glfw.GLFW_KEY_F6 => .F6,
            glfw.GLFW_KEY_F7 => .F7,
            glfw.GLFW_KEY_F8 => .F8,
            glfw.GLFW_KEY_F9 => .F9,
            glfw.GLFW_KEY_F10 => .F10,
            glfw.GLFW_KEY_F11 => .F11,
            glfw.GLFW_KEY_F12 => .F12,
            glfw.GLFW_KEY_F13 => .F13,
            glfw.GLFW_KEY_F14 => .F14,
            glfw.GLFW_KEY_F15 => .F15,
            glfw.GLFW_KEY_F16 => .F16,
            glfw.GLFW_KEY_F17 => .F17,
            glfw.GLFW_KEY_F18 => .F18,
            glfw.GLFW_KEY_F19 => .F19,
            glfw.GLFW_KEY_F20 => .F20,
            glfw.GLFW_KEY_F21 => .F21,
            glfw.GLFW_KEY_F22 => .F22,
            glfw.GLFW_KEY_F23 => .F23,
            glfw.GLFW_KEY_F24 => .F24,
            glfw.GLFW_KEY_F25 => .F25,
            glfw.GLFW_KEY_KP_0 => .Kp0,
            glfw.GLFW_KEY_KP_1 => .Kp1,
            glfw.GLFW_KEY_KP_2 => .Kp2,
            glfw.GLFW_KEY_KP_3 => .Kp3,
            glfw.GLFW_KEY_KP_4 => .Kp4,
            glfw.GLFW_KEY_KP_5 => .Kp5,
            glfw.GLFW_KEY_KP_6 => .Kp6,
            glfw.GLFW_KEY_KP_7 => .Kp7,
            glfw.GLFW_KEY_KP_8 => .Kp8,
            glfw.GLFW_KEY_KP_9 => .Kp9,
            glfw.GLFW_KEY_KP_DECIMAL => .KpDecimal,
            glfw.GLFW_KEY_KP_DIVIDE => .KpDivide,
            glfw.GLFW_KEY_KP_MULTIPLY => .KpMultiply,
            glfw.GLFW_KEY_KP_SUBTRACT => .KpSubtract,
            glfw.GLFW_KEY_KP_ADD => .KpAdd,
            glfw.GLFW_KEY_KP_ENTER => .KpEnter,
            glfw.GLFW_KEY_KP_EQUAL => .KpEqual,
            glfw.GLFW_KEY_LEFT_SHIFT => .LeftShift,
            glfw.GLFW_KEY_LEFT_CONTROL => .LeftControl,
            glfw.GLFW_KEY_LEFT_ALT => .LeftAlt,
            glfw.GLFW_KEY_LEFT_SUPER => .LeftSuper,
            glfw.GLFW_KEY_RIGHT_SHIFT => .RightShift,
            glfw.GLFW_KEY_RIGHT_CONTROL => .RightControl,
            glfw.GLFW_KEY_RIGHT_ALT => .RightAlt,
            glfw.GLFW_KEY_RIGHT_SUPER => .RightSuper,
            glfw.GLFW_KEY_MENU => .Menu,
            else => .Unknown,
        };
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

pub const ZEventCallback = *const fn (*Application, ZEvent) void;

pub fn mouseButtonCallback(window: c.Window, btn: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = mods;

    const isPress = action == glfw.GLFW_PRESS;
    const isRelease = action == glfw.GLFW_RELEASE;
    if (!isPress and !isRelease) {
        return;
    }

    // Only handle buttons 0-7
    if (btn < 0 or btn > 7) {
        return;
    }

    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    const button: MouseButton = @enumFromInt(@as(u8, @intCast(btn)));
    const ev: ZEvent = if (isPress)
        ZEvent{ .MousePressed = button }
    else
        ZEvent{ .MouseReleased = button };

    windowData.eventCallback(windowData.app_ptr.?, ev);
}

pub fn keyButtonCallback(window: c.Window, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = mods;
    _ = scancode;

    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    const mappedKey = Key.fromGLFW(key);
    if (mappedKey == .Unknown) {
        return;
    }

    var ev: ZEvent = undefined;
    if (action == glfw.GLFW_PRESS) {
        ev = ZEvent{ .KeyPressed = mappedKey };
    } else if (action == glfw.GLFW_REPEAT) {
        ev = ZEvent{ .KeyRepeated = mappedKey };
    } else if (action == glfw.GLFW_RELEASE) {
        ev = ZEvent{ .KeyReleased = mappedKey };
    }

    windowData.eventCallback(windowData.app_ptr.?, ev);
}

pub fn windowResizeCallback(window: c.Window, width: c_int, height: c_int) callconv(.c) void {
    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    windowData.*.height = @intCast(height);
    windowData.*.width = @intCast(width);

    const ev = ZEvent{ .WindowResize = .{
        .height = @intCast(height),
        .width = @intCast(width),
    } };
    windowData.eventCallback(windowData.app_ptr.?, ev);
}

pub fn framebufferSizeCallback(window: c.Window, width: c_int, height: c_int) callconv(.c) void {
    gl.glViewport(0, 0, @intCast(width), @intCast(height));

    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    const ev = ZEvent{ .FramebufferResize = .{
        .width = @intCast(width),
        .height = @intCast(height),
    } };
    windowData.eventCallback(windowData.app_ptr.?, ev);
}

pub fn contentScaleCallback(window: c.Window, xscale: f32, yscale: f32) callconv(.c) void {
    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    const ev = ZEvent{ .ContentScaleChange = .{ .x = xscale, .y = yscale } };
    windowData.eventCallback(windowData.app_ptr.?, ev);
}

pub fn windowCloseCallback(window: c.Window) callconv(.c) void {
    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    const ev: ZEvent = .WindowClose;
    windowData.eventCallback(windowData.app_ptr.?, ev);
}

pub fn cursorPosCallback(window: c.Window, x: f64, y: f64) callconv(.c) void {
    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    const ev = ZEvent{ .MouseMove = .{ .x = @floatCast(x), .y = @floatCast(y) } };
    windowData.eventCallback(windowData.app_ptr.?, ev);
}

pub fn cursorScrollCallback(window: c.Window, x: f64, y: f64) callconv(.c) void {
    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    const ev = ZEvent{ .MouseScroll = .{ .x = @floatCast(x), .y = @floatCast(y) } };
    windowData.eventCallback(windowData.app_ptr.?, ev);
}

pub fn charCallback(window: c.Window, codepoint: c_uint) callconv(.c) void {
    const windowDataPtr = glfw.glfwGetWindowUserPointer(window).?;
    const windowData: *WindowData = @ptrCast(@alignCast(windowDataPtr));

    const ev = ZEvent{ .CharInput = @intCast(codepoint) };
    windowData.eventCallback(windowData.app_ptr.?, ev);
}

const std = @import("std");

test "Key.fromGLFW converts letter keys correctly" {
    try std.testing.expectEqual(Key.A, Key.fromGLFW(glfw.GLFW_KEY_A));
    try std.testing.expectEqual(Key.B, Key.fromGLFW(glfw.GLFW_KEY_B));
    try std.testing.expectEqual(Key.Z, Key.fromGLFW(glfw.GLFW_KEY_Z));
}

test "Key.fromGLFW converts number keys correctly" {
    try std.testing.expectEqual(Key.Num0, Key.fromGLFW(glfw.GLFW_KEY_0));
    try std.testing.expectEqual(Key.Num5, Key.fromGLFW(glfw.GLFW_KEY_5));
    try std.testing.expectEqual(Key.Num9, Key.fromGLFW(glfw.GLFW_KEY_9));
}

test "Key.fromGLFW converts special keys correctly" {
    try std.testing.expectEqual(Key.Space, Key.fromGLFW(glfw.GLFW_KEY_SPACE));
    try std.testing.expectEqual(Key.Enter, Key.fromGLFW(glfw.GLFW_KEY_ENTER));
    try std.testing.expectEqual(Key.Escape, Key.fromGLFW(glfw.GLFW_KEY_ESCAPE));
    try std.testing.expectEqual(Key.Tab, Key.fromGLFW(glfw.GLFW_KEY_TAB));
    try std.testing.expectEqual(Key.Backspace, Key.fromGLFW(glfw.GLFW_KEY_BACKSPACE));
}

test "Key.fromGLFW converts arrow keys correctly" {
    try std.testing.expectEqual(Key.Up, Key.fromGLFW(glfw.GLFW_KEY_UP));
    try std.testing.expectEqual(Key.Down, Key.fromGLFW(glfw.GLFW_KEY_DOWN));
    try std.testing.expectEqual(Key.Left, Key.fromGLFW(glfw.GLFW_KEY_LEFT));
    try std.testing.expectEqual(Key.Right, Key.fromGLFW(glfw.GLFW_KEY_RIGHT));
}

test "Key.fromGLFW converts function keys correctly" {
    try std.testing.expectEqual(Key.F1, Key.fromGLFW(glfw.GLFW_KEY_F1));
    try std.testing.expectEqual(Key.F5, Key.fromGLFW(glfw.GLFW_KEY_F5));
    try std.testing.expectEqual(Key.F12, Key.fromGLFW(glfw.GLFW_KEY_F12));
}

test "Key.fromGLFW converts modifier keys correctly" {
    try std.testing.expectEqual(Key.LeftShift, Key.fromGLFW(glfw.GLFW_KEY_LEFT_SHIFT));
    try std.testing.expectEqual(Key.RightShift, Key.fromGLFW(glfw.GLFW_KEY_RIGHT_SHIFT));
    try std.testing.expectEqual(Key.LeftControl, Key.fromGLFW(glfw.GLFW_KEY_LEFT_CONTROL));
    try std.testing.expectEqual(Key.RightControl, Key.fromGLFW(glfw.GLFW_KEY_RIGHT_CONTROL));
    try std.testing.expectEqual(Key.LeftAlt, Key.fromGLFW(glfw.GLFW_KEY_LEFT_ALT));
    try std.testing.expectEqual(Key.RightAlt, Key.fromGLFW(glfw.GLFW_KEY_RIGHT_ALT));
}

test "Key.fromGLFW converts keypad keys correctly" {
    try std.testing.expectEqual(Key.Kp0, Key.fromGLFW(glfw.GLFW_KEY_KP_0));
    try std.testing.expectEqual(Key.Kp9, Key.fromGLFW(glfw.GLFW_KEY_KP_9));
    try std.testing.expectEqual(Key.KpAdd, Key.fromGLFW(glfw.GLFW_KEY_KP_ADD));
    try std.testing.expectEqual(Key.KpSubtract, Key.fromGLFW(glfw.GLFW_KEY_KP_SUBTRACT));
    try std.testing.expectEqual(Key.KpMultiply, Key.fromGLFW(glfw.GLFW_KEY_KP_MULTIPLY));
    try std.testing.expectEqual(Key.KpDivide, Key.fromGLFW(glfw.GLFW_KEY_KP_DIVIDE));
}

test "Key.fromGLFW returns Unknown for invalid keys" {
    try std.testing.expectEqual(Key.Unknown, Key.fromGLFW(-1));
    try std.testing.expectEqual(Key.Unknown, Key.fromGLFW(9999));
}

test "MouseButton enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(MouseButton.Left));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(MouseButton.Right));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(MouseButton.Middle));
}

test "ZEvent union creation" {
    const close_event = ZEvent.WindowClose;
    try std.testing.expect(close_event == .WindowClose);

    const resize_event = ZEvent{ .WindowResize = .{ .width = 800, .height = 600 } };
    try std.testing.expectEqual(@as(u32, 800), resize_event.WindowResize.width);
    try std.testing.expectEqual(@as(u32, 600), resize_event.WindowResize.height);

    const key_event = ZEvent{ .KeyPressed = Key.A };
    try std.testing.expectEqual(Key.A, key_event.KeyPressed);

    const mouse_event = ZEvent{ .MousePressed = MouseButton.Left };
    try std.testing.expectEqual(MouseButton.Left, mouse_event.MousePressed);

    const scroll_event = ZEvent{ .MouseScroll = .{ .x = 1.5, .y = -2.0 } };
    try std.testing.expectEqual(@as(f64, 1.5), scroll_event.MouseScroll.x);
    try std.testing.expectEqual(@as(f64, -2.0), scroll_event.MouseScroll.y);
}
