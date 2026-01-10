const std = @import("std");

const event = @import("event.zig");

pub const InputManager = struct {
    mouse_pos: struct {
        x: f32,
        y: f32,
    },
    mouse_delta: struct {
        x: f32,
        y: f32,
    },
    mouse_scroll: struct {
        x: f32,
        y: f32,
    },
    mouse_scroll_delta: struct {
        x: f32,
        y: f32,
    },
    pressed_keys: [512]bool,
    released_keys: [512]bool,
    held_keys: [512]bool,

    pressed_buttons: [8]bool,
    released_buttons: [8]bool,
    held_buttons: [8]bool,

    pub fn init() InputManager {
        return InputManager{
            .mouse_pos = .{ .x = 0.0, .y = 0.0 },
            .mouse_delta = .{ .x = 0.0, .y = 0.0 },
            .mouse_scroll = .{ .x = 0.0, .y = 0.0 },
            .mouse_scroll_delta = .{ .x = 0.0, .y = 0.0 },
            .pressed_keys = [_]bool{false} ** 512,
            .released_keys = [_]bool{false} ** 512,
            .held_keys = [_]bool{false} ** 512,
            .pressed_buttons = [_]bool{false} ** 8,
            .released_buttons = [_]bool{false} ** 8,
            .held_buttons = [_]bool{false} ** 8,
        };
    }

    pub fn clear(self: *InputManager) void {
        @memset(&self.pressed_keys, false);
        @memset(&self.released_keys, false);
        @memset(&self.pressed_buttons, false);
        @memset(&self.released_buttons, false);
        self.mouse_scroll = .{ .x = 0.0, .y = 0.0 };
        self.mouse_delta = .{ .x = 0.0, .y = 0.0 };
    }

    pub fn update(self: *InputManager, ev: event.ZEvent) void {
        switch (ev) {
            event.ZEvent.MouseMove => |move_event| {
                self.mouse_delta.x = move_event.x - self.mouse_pos.x;
                self.mouse_delta.y = move_event.y - self.mouse_pos.y;
                self.mouse_pos.x = move_event.x;
                self.mouse_pos.y = move_event.y;
            },
            event.ZEvent.MouseScroll => |scroll_event| {
                self.mouse_scroll_delta.x = scroll_event.x - self.mouse_scroll.x;
                self.mouse_scroll_delta.y = scroll_event.y - self.mouse_scroll.y;
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
                self.held_buttons[button] = true;
            },
            event.ZEvent.MouseReleased => |button_event| {
                const button = @intFromEnum(button_event);
                self.released_buttons[button] = true;
                self.held_buttons[button] = false;
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

    pub fn isButtonHeld(self: *InputManager, button: event.MouseButton) bool {
        const b = @intFromEnum(button);
        return self.held_buttons[b];
    }

    pub fn isScrollingY(self: *InputManager) bool {
        return self.mouse_scroll.y != 0;
    }

    pub fn isScrollingX(self: *InputManager) bool {
        return self.mouse_scroll.x != 0;
    }
};

pub var Input: InputManager = InputManager.init();

test "InputManager initialization" {
    const input = InputManager.init();

    try std.testing.expectEqual(@as(f64, 0.0), input.mouse_pos.x);
    try std.testing.expectEqual(@as(f64, 0.0), input.mouse_pos.y);
    try std.testing.expectEqual(@as(f64, 0.0), input.mouse_scroll.x);
    try std.testing.expectEqual(@as(f64, 0.0), input.mouse_scroll.y);

    for (input.pressed_keys) |key| {
        try std.testing.expect(!key);
    }
    for (input.released_keys) |key| {
        try std.testing.expect(!key);
    }
    for (input.held_keys) |key| {
        try std.testing.expect(!key);
    }
    for (input.pressed_buttons) |button| {
        try std.testing.expect(!button);
    }
    for (input.released_buttons) |button| {
        try std.testing.expect(!button);
    }
}

test "InputManager key press detection" {
    var input = InputManager.init();

    const press_event = event.ZEvent{ .KeyPressed = event.Key.A };
    input.update(press_event);

    try std.testing.expect(input.isKeyPressed(.A));
    try std.testing.expect(input.isKeyHeld(.A));
    try std.testing.expect(!input.isKeyReleased(.A));
    try std.testing.expect(!input.isKeyPressed(.B));
}

test "InputManager key release detection" {
    var input = InputManager.init();

    const press_event = event.ZEvent{ .KeyPressed = event.Key.Space };
    input.update(press_event);

    try std.testing.expect(input.isKeyHeld(.Space));

    const release_event = event.ZEvent{ .KeyReleased = event.Key.Space };
    input.update(release_event);

    try std.testing.expect(input.isKeyReleased(.Space));
    try std.testing.expect(!input.isKeyHeld(.Space));
}

test "InputManager key repeated detection" {
    var input = InputManager.init();

    const repeat_event = event.ZEvent{ .KeyRepeated = event.Key.W };
    input.update(repeat_event);

    try std.testing.expect(input.isKeyPressed(.W));
    try std.testing.expect(input.isKeyHeld(.W));
}

test "InputManager mouse button press detection" {
    var input = InputManager.init();

    const press_event = event.ZEvent{ .MousePressed = event.MouseButton.Left };
    input.update(press_event);

    try std.testing.expect(input.isButtonPressed(.Left));
    try std.testing.expect(!input.isButtonPressed(.Right));
}

test "InputManager mouse button release detection" {
    var input = InputManager.init();

    const press_event = event.ZEvent{ .MousePressed = event.MouseButton.Right };
    input.update(press_event);

    const release_event = event.ZEvent{ .MouseReleased = event.MouseButton.Right };
    input.update(release_event);

    try std.testing.expect(input.isButtonReleased(.Right));
}

test "InputManager mouse position tracking" {
    var input = InputManager.init();

    const move_event = event.ZEvent{ .MouseMove = .{ .x = 100.5, .y = 200.75 } };
    input.update(move_event);

    try std.testing.expectEqual(@as(f64, 100.5), input.mouse_pos.x);
    try std.testing.expectEqual(@as(f64, 200.75), input.mouse_pos.y);

    const move_event2 = event.ZEvent{ .MouseMove = .{ .x = 50.0, .y = 75.0 } };
    input.update(move_event2);

    try std.testing.expectEqual(@as(f64, 50.0), input.mouse_pos.x);
    try std.testing.expectEqual(@as(f64, 75.0), input.mouse_pos.y);
}

test "InputManager mouse scroll accumulation" {
    var input = InputManager.init();

    const scroll_event1 = event.ZEvent{ .MouseScroll = .{ .x = 1.0, .y = 2.0 } };
    input.update(scroll_event1);

    try std.testing.expectEqual(@as(f64, 1.0), input.mouse_scroll.x);
    try std.testing.expectEqual(@as(f64, 2.0), input.mouse_scroll.y);

    const scroll_event2 = event.ZEvent{ .MouseScroll = .{ .x = 0.5, .y = -1.0 } };
    input.update(scroll_event2);

    try std.testing.expectEqual(@as(f64, 1.5), input.mouse_scroll.x);
    try std.testing.expectEqual(@as(f64, 1.0), input.mouse_scroll.y);
}

test "InputManager clear resets all state" {
    var input = InputManager.init();

    input.update(event.ZEvent{ .KeyPressed = event.Key.A });
    input.update(event.ZEvent{ .MousePressed = event.MouseButton.Left });
    input.update(event.ZEvent{ .MouseMove = .{ .x = 100.0, .y = 200.0 } });
    input.update(event.ZEvent{ .MouseScroll = .{ .x = 5.0, .y = 10.0 } });

    try std.testing.expect(input.isKeyPressed(.A));
    try std.testing.expect(input.isButtonPressed(.Left));

    input.clear();

    try std.testing.expect(!input.isKeyPressed(.A));
    try std.testing.expect(!input.isButtonPressed(.Left));
    try std.testing.expectEqual(@as(f64, 100), input.mouse_pos.x);
    try std.testing.expectEqual(@as(f64, 200), input.mouse_pos.y);
    try std.testing.expectEqual(@as(f64, 0.0), input.mouse_delta.x);
    try std.testing.expectEqual(@as(f64, 0.0), input.mouse_delta.y);
    try std.testing.expectEqual(@as(f64, 0.0), input.mouse_scroll.x);
    try std.testing.expectEqual(@as(f64, 0.0), input.mouse_scroll.y);
}

test "InputManager multiple keys simultaneously" {
    var input = InputManager.init();

    input.update(event.ZEvent{ .KeyPressed = event.Key.W });
    input.update(event.ZEvent{ .KeyPressed = event.Key.A });
    input.update(event.ZEvent{ .KeyPressed = event.Key.LeftShift });

    try std.testing.expect(input.isKeyHeld(.W));
    try std.testing.expect(input.isKeyHeld(.A));
    try std.testing.expect(input.isKeyHeld(.LeftShift));

    input.update(event.ZEvent{ .KeyReleased = event.Key.A });

    try std.testing.expect(input.isKeyHeld(.W));
    try std.testing.expect(!input.isKeyHeld(.A));
    try std.testing.expect(input.isKeyReleased(.A));
    try std.testing.expect(input.isKeyHeld(.LeftShift));
}

test "InputManager window close event ignored" {
    var input = InputManager.init();

    const initial_state = input;
    input.update(event.ZEvent.WindowClose);

    try std.testing.expectEqual(initial_state.mouse_pos.x, input.mouse_pos.x);
    try std.testing.expectEqual(initial_state.mouse_pos.y, input.mouse_pos.y);
}
