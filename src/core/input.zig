const std = @import("std");
const event = @import("event.zig");

pub const Position = struct {
    x: f32,
    y: f32,
};

pub const InputManager = struct {
    mouse_pos: Position,
    mouse_delta: Position,
    mouse_scroll: Position,
    pressed_keys: [512]bool,
    released_keys: [512]bool,
    held_keys: [512]bool,

    pressed_buttons: [8]bool,
    released_buttons: [8]bool,
    held_buttons: [8]bool,

    var instance: ?InputManager = null;
    var once = std.once(init);

    fn init() void {
        instance = InputManager{
            .mouse_pos = .{ .x = 0.0, .y = 0.0 },
            .mouse_delta = .{ .x = 0.0, .y = 0.0 },
            .mouse_scroll = .{ .x = 0.0, .y = 0.0 },
            .pressed_keys = [_]bool{false} ** 512,
            .released_keys = [_]bool{false} ** 512,
            .held_keys = [_]bool{false} ** 512,
            .pressed_buttons = [_]bool{false} ** 8,
            .released_buttons = [_]bool{false} ** 8,
            .held_buttons = [_]bool{false} ** 8,
        };
    }

    inline fn getInstance() *InputManager {
        once.call();
        return &instance.?;
    }

    pub fn Clear() void {
        const self = getInstance();
        @memset(&self.pressed_keys, false);
        @memset(&self.released_keys, false);
        @memset(&self.pressed_buttons, false);
        @memset(&self.released_buttons, false);
        self.mouse_scroll = .{ .x = 0.0, .y = 0.0 };
        self.mouse_delta = .{ .x = 0.0, .y = 0.0 };
    }

    pub fn Update(ev: event.ZEvent) void {
        const self = getInstance();
        switch (ev) {
            .MouseMove => |move_event| {
                self.mouse_delta.x = move_event.x - self.mouse_pos.x;
                self.mouse_delta.y = move_event.y - self.mouse_pos.y;
                self.mouse_pos.x = move_event.x;
                self.mouse_pos.y = move_event.y;
            },
            .MouseScroll => |scroll_event| {
                self.mouse_scroll.x += scroll_event.x;
                self.mouse_scroll.y += scroll_event.y;
            },
            .KeyPressed => |key_event| {
                const key = @intFromEnum(key_event);
                self.pressed_keys[key] = true;
                self.held_keys[key] = true;
            },
            .KeyRepeated => |key_event| {
                const key = @intFromEnum(key_event);
                self.pressed_keys[key] = true;
                self.held_keys[key] = true;
            },
            .KeyReleased => |key_event| {
                const key = @intFromEnum(key_event);
                self.released_keys[key] = true;
                self.held_keys[key] = false;
            },
            .MousePressed => |mouse_event| {
                const button = @intFromEnum(mouse_event);
                self.pressed_buttons[button] = true;
                self.held_buttons[button] = true;
            },
            .MouseReleased => |mouse_event| {
                const button = @intFromEnum(mouse_event);
                self.pressed_buttons[button] = true;
                self.held_buttons[button] = false;
            },
            else => {},
        }
    }

    pub fn GetMousePos() Position {
        const self = getInstance();
        return self.mouse_pos;
    }

    pub fn IsKeyPressed(key: event.Key) bool {
        const self = getInstance();
        const k = @intFromEnum(key);
        return self.pressed_keys[k];
    }

    pub fn IsKeyReleased(key: event.Key) bool {
        const self = getInstance();
        const k = @intFromEnum(key);
        return self.released_keys[k];
    }

    pub fn IsKeyHeld(key: event.Key) bool {
        const self = getInstance();
        const k = @intFromEnum(key);
        return self.held_keys[k];
    }

    pub fn IsButtonPressed(key: event.MouseButton) bool {
        const self = getInstance();
        const b = @intFromEnum(key);
        return self.pressed_buttons[b];
    }

    pub fn IsButtonReleased(key: event.MouseButton) bool {
        const self = getInstance();
        const b = @intFromEnum(key);
        return self.released_buttons[b];
    }

    pub fn IsButtonHeld(key: event.MouseButton) bool {
        const self = getInstance();
        const b = @intFromEnum(key);
        return self.held_buttons[b];
    }

    pub fn IsScrollingY() bool {
        const self = getInstance();
        return self.mouse_scroll.y != 0;
    }

    pub fn IsScrollingX() bool {
        const self = getInstance();
        return self.mouse_scroll.x != 0;
    }

    pub fn GetMouseMoveDelta() Position {
        const self = getInstance();
        return self.mouse_delta;
    }

    pub fn GetMouseMoveScroll() Position {
        const self = getInstance();
        return self.mouse_scroll;
    }
};
