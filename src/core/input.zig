const std = @import("std");

const event = @import("event.zig");

pub const InputManager = struct {
    mouse_pos: struct {
        x: f64,
        y: f64,
    },
    mouse_scroll: struct {
        x: f64,
        y: f64,
    },
    pressed_keys: [512]bool,
    released_keys: [512]bool,
    held_keys: [512]bool,

    pressed_buttons: [8]bool,
    released_buttons: [8]bool,

    pub fn init() InputManager {
        return InputManager{
            .mouse_pos = .{ .x = 0.0, .y = 0.0 },
            .mouse_scroll = .{ .x = 0.0, .y = 0.0 },
            .pressed_keys = [_]bool{false} ** 512,
            .released_keys = [_]bool{false} ** 512,
            .held_keys = [_]bool{false} ** 512,
            .pressed_buttons = [_]bool{false} ** 8,
            .released_buttons = [_]bool{false} ** 8,
        };
    }

    pub fn clear(self: *InputManager) void {
        @memset(&self.pressed_keys, false);
        @memset(&self.released_keys, false);
        @memset(&self.held_keys, false);
        @memset(&self.pressed_buttons, false);
        @memset(&self.released_buttons, false);
        self.mouse_scroll = .{ .x = 0.0, .y = 0.0 };
        self.mouse_pos = .{ .x = 0.0, .y = 0.0 };
    }

    pub fn update(self: *InputManager, ev: event.ZEvent) void {
        switch (ev) {
            event.ZEvent.MouseMove => |move_event| {
                self.mouse_pos.x = move_event.x;
                self.mouse_pos.y = move_event.y;
            },
            event.ZEvent.MouseScroll => |scroll_event| {
                self.mouse_scroll.x += scroll_event.x;
                self.mouse_scroll.y += scroll_event.y;
            },
            event.ZEvent.KeyPressed => |key_event| {
                const key = @intFromEnum(key_event);
                self.pressed_keys[key] = true;
                self.held_keys[key] = true;
            },
            event.ZEvent.KeyRepeated => |key_event| {
                const key = @intFromEnum(key_event);
                self.pressed_keys[key] = true;
                self.held_keys[key] = true;
            },
            event.ZEvent.KeyReleased => |key_event| {
                const key = @intFromEnum(key_event);
                self.released_keys[key] = true;
                self.held_keys[key] = false;
            },
            event.ZEvent.MousePressed => |button_event| {
                const button = @intFromEnum(button_event);
                self.pressed_buttons[button] = true;
            },
            event.ZEvent.MouseReleased => |button_event| {
                const button = @intFromEnum(button_event);
                self.released_buttons[button] = true;
            },
            else => {},
        }
    }

    pub fn isKeyPressed(self: *InputManager, key: event.Key) bool {
        const k = @intFromEnum(key);
        return self.pressed_keys[k];
    }

    pub fn isKeyReleased(self: *InputManager, key: event.Key) bool {
        const k = @intFromEnum(key);
        return self.released_keys[k];
    }

    pub fn isKeyHeld(self: *InputManager, key: event.Key) bool {
        const k = @intFromEnum(key);
        return self.held_keys[k];
    }

    pub fn isButtonPressed(self: *InputManager, button: event.MouseButton) bool {
        const b = @intFromEnum(button);
        return self.pressed_buttons[b];
    }

    pub fn isButtonReleased(self: *InputManager, button: event.MouseButton) bool {
        const b = @intFromEnum(button);
        return self.released_buttons[b];
    }
};

pub var Input: InputManager = InputManager.init();
