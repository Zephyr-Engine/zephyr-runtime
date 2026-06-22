const std = @import("std");

const event = @import("event.zig");

pub const Position = struct {
    x: f32,
    y: f32,
};

pub const InputState = struct {
    mouse_pos: Position = .{ .x = 0, .y = 0 },
    mouse_delta: Position = .{ .x = 0, .y = 0 },
    mouse_scroll: Position = .{ .x = 0, .y = 0 },
    pressed_keys: [512]bool = [_]bool{false} ** 512,
    released_keys: [512]bool = [_]bool{false} ** 512,
    held_keys: [512]bool = [_]bool{false} ** 512,
    pressed_buttons: [8]bool = [_]bool{false} ** 8,
    released_buttons: [8]bool = [_]bool{false} ** 8,
    held_buttons: [8]bool = [_]bool{false} ** 8,

    pub fn isKeyHeld(self: *const InputState, key: event.Key) bool {
        return self.held_keys[@intFromEnum(key)];
    }

    pub fn isButtonHeld(self: *const InputState, button: event.MouseButton) bool {
        return self.held_buttons[@intFromEnum(button)];
    }
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

    inline fn getInstance() *InputManager {
        if (instance == null) {
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
                self.released_buttons[button] = true;
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

    pub fn snapshot() InputState {
        const self = getInstance();
        return .{
            .mouse_pos = self.mouse_pos,
            .mouse_delta = self.mouse_delta,
            .mouse_scroll = self.mouse_scroll,
            .pressed_keys = self.pressed_keys,
            .released_keys = self.released_keys,
            .held_keys = self.held_keys,
            .pressed_buttons = self.pressed_buttons,
            .released_buttons = self.released_buttons,
            .held_buttons = self.held_buttons,
        };
    }
};

test "InputManager initialization" {
    InputManager.Clear();

    const self = InputManager.getInstance();

    try std.testing.expectEqual(@as(f32, 0.0), self.mouse_pos.x);
    try std.testing.expectEqual(@as(f32, 0.0), self.mouse_pos.y);
    try std.testing.expectEqual(@as(f32, 0.0), self.mouse_scroll.x);
    try std.testing.expectEqual(@as(f32, 0.0), self.mouse_scroll.y);

    for (self.pressed_keys) |key| {
        try std.testing.expect(!key);
    }
    for (self.released_keys) |key| {
        try std.testing.expect(!key);
    }
    for (self.held_keys) |key| {
        try std.testing.expect(!key);
    }
    for (self.pressed_buttons) |button| {
        try std.testing.expect(!button);
    }
    for (self.released_buttons) |button| {
        try std.testing.expect(!button);
    }
}

test "InputManager key press detection" {
    InputManager.Clear();

    const press_event = event.ZEvent{ .KeyPressed = event.Key.A };
    InputManager.Update(press_event);

    try std.testing.expect(InputManager.IsKeyPressed(.A));
    try std.testing.expect(InputManager.IsKeyHeld(.A));
    try std.testing.expect(!InputManager.IsKeyReleased(.A));
    try std.testing.expect(!InputManager.IsKeyPressed(.B));
}

test "InputManager key release detection" {
    InputManager.Clear();

    const press_event = event.ZEvent{ .KeyPressed = event.Key.Space };
    InputManager.Update(press_event);

    try std.testing.expect(InputManager.IsKeyHeld(.Space));

    const release_event = event.ZEvent{ .KeyReleased = event.Key.Space };
    InputManager.Update(release_event);

    try std.testing.expect(InputManager.IsKeyReleased(.Space));
    try std.testing.expect(!InputManager.IsKeyHeld(.Space));
}

test "InputManager key repeated detection" {
    InputManager.Clear();

    const repeat_event = event.ZEvent{ .KeyRepeated = event.Key.W };
    InputManager.Update(repeat_event);

    try std.testing.expect(InputManager.IsKeyPressed(.W));
    try std.testing.expect(InputManager.IsKeyHeld(.W));
}

test "InputManager mouse button press detection" {
    InputManager.Clear();

    const press_event = event.ZEvent{ .MousePressed = event.MouseButton.Left };
    InputManager.Update(press_event);

    try std.testing.expect(InputManager.IsButtonPressed(.Left));
    try std.testing.expect(!InputManager.IsButtonPressed(.Right));
}

test "InputManager mouse button release detection" {
    InputManager.Clear();

    const press_event = event.ZEvent{ .MousePressed = event.MouseButton.Right };
    InputManager.Update(press_event);

    const release_event = event.ZEvent{ .MouseReleased = event.MouseButton.Right };
    InputManager.Update(release_event);

    try std.testing.expect(InputManager.IsButtonReleased(.Right));
}

test "InputManager mouse position tracking" {
    InputManager.Clear();

    const move_event = event.ZEvent{ .MouseMove = .{ .x = 100.5, .y = 200.75 } };
    InputManager.Update(move_event);

    const self = InputManager.getInstance();
    try std.testing.expectEqual(@as(f32, 100.5), self.mouse_pos.x);
    try std.testing.expectEqual(@as(f32, 200.75), self.mouse_pos.y);

    const move_event2 = event.ZEvent{ .MouseMove = .{ .x = 50.0, .y = 75.0 } };
    InputManager.Update(move_event2);

    try std.testing.expectEqual(@as(f32, 50.0), self.mouse_pos.x);
    try std.testing.expectEqual(@as(f32, 75.0), self.mouse_pos.y);
}

test "InputManager mouse scroll accumulation" {
    InputManager.Clear();

    const scroll_event1 = event.ZEvent{ .MouseScroll = .{ .x = 1.0, .y = 2.0 } };
    InputManager.Update(scroll_event1);

    const scroll = InputManager.GetMouseMoveScroll();
    try std.testing.expectEqual(@as(f32, 1.0), scroll.x);
    try std.testing.expectEqual(@as(f32, 2.0), scroll.y);

    const scroll_event2 = event.ZEvent{ .MouseScroll = .{ .x = 0.5, .y = -1.0 } };
    InputManager.Update(scroll_event2);

    const scroll2 = InputManager.GetMouseMoveScroll();
    try std.testing.expectEqual(@as(f32, 1.5), scroll2.x);
    try std.testing.expectEqual(@as(f32, 1.0), scroll2.y);
}

test "InputManager clear resets all state" {
    InputManager.Clear();

    InputManager.Update(event.ZEvent{ .KeyPressed = event.Key.A });
    InputManager.Update(event.ZEvent{ .MousePressed = event.MouseButton.Left });
    InputManager.Update(event.ZEvent{ .MouseMove = .{ .x = 100.0, .y = 200.0 } });
    InputManager.Update(event.ZEvent{ .MouseScroll = .{ .x = 5.0, .y = 10.0 } });

    try std.testing.expect(InputManager.IsKeyPressed(.A));
    try std.testing.expect(InputManager.IsButtonPressed(.Left));

    InputManager.Clear();

    try std.testing.expect(!InputManager.IsKeyPressed(.A));
    try std.testing.expect(!InputManager.IsButtonPressed(.Left));

    const self = InputManager.getInstance();
    try std.testing.expectEqual(@as(f32, 100.0), self.mouse_pos.x);
    try std.testing.expectEqual(@as(f32, 200.0), self.mouse_pos.y);
    try std.testing.expectEqual(@as(f32, 0.0), self.mouse_delta.x);
    try std.testing.expectEqual(@as(f32, 0.0), self.mouse_delta.y);
    try std.testing.expectEqual(@as(f32, 0.0), self.mouse_scroll.x);
    try std.testing.expectEqual(@as(f32, 0.0), self.mouse_scroll.y);
}

test "InputManager multiple keys simultaneously" {
    InputManager.Clear();

    InputManager.Update(event.ZEvent{ .KeyPressed = event.Key.W });
    InputManager.Update(event.ZEvent{ .KeyPressed = event.Key.A });
    InputManager.Update(event.ZEvent{ .KeyPressed = event.Key.LeftShift });

    try std.testing.expect(InputManager.IsKeyHeld(.W));
    try std.testing.expect(InputManager.IsKeyHeld(.A));
    try std.testing.expect(InputManager.IsKeyHeld(.LeftShift));

    InputManager.Update(event.ZEvent{ .KeyReleased = event.Key.A });

    try std.testing.expect(InputManager.IsKeyHeld(.W));
    try std.testing.expect(!InputManager.IsKeyHeld(.A));
    try std.testing.expect(InputManager.IsKeyReleased(.A));
    try std.testing.expect(InputManager.IsKeyHeld(.LeftShift));
}

test "InputManager window close event ignored" {
    InputManager.Clear();

    const self = InputManager.getInstance();
    const initial_x = self.mouse_pos.x;
    const initial_y = self.mouse_pos.y;

    InputManager.Update(event.ZEvent.WindowClose);

    try std.testing.expectEqual(initial_x, self.mouse_pos.x);
    try std.testing.expectEqual(initial_y, self.mouse_pos.y);
}

test "InputManager mouse button held detection" {
    InputManager.Clear();

    const press_event = event.ZEvent{ .MousePressed = event.MouseButton.Left };
    InputManager.Update(press_event);

    try std.testing.expect(InputManager.IsButtonHeld(.Left));
    try std.testing.expect(!InputManager.IsButtonHeld(.Right));

    const release_event = event.ZEvent{ .MouseReleased = event.MouseButton.Left };
    InputManager.Update(release_event);

    try std.testing.expect(!InputManager.IsButtonHeld(.Left));
}

test "InputManager scroll detection Y axis" {
    InputManager.Clear();

    try std.testing.expect(!InputManager.IsScrollingY());

    const scroll_event = event.ZEvent{ .MouseScroll = .{ .x = 0.0, .y = 1.5 } };
    InputManager.Update(scroll_event);

    try std.testing.expect(InputManager.IsScrollingY());

    InputManager.Clear();
    try std.testing.expect(!InputManager.IsScrollingY());
}

test "InputManager scroll detection X axis" {
    InputManager.Clear();

    try std.testing.expect(!InputManager.IsScrollingX());

    const scroll_event = event.ZEvent{ .MouseScroll = .{ .x = 2.0, .y = 0.0 } };
    InputManager.Update(scroll_event);

    try std.testing.expect(InputManager.IsScrollingX());

    InputManager.Clear();
    try std.testing.expect(!InputManager.IsScrollingX());
}

test "InputManager mouse move delta tracking" {
    InputManager.Clear();

    // Set initial position
    const move_event1 = event.ZEvent{ .MouseMove = .{ .x = 100.0, .y = 200.0 } };
    InputManager.Update(move_event1);

    // Move to new position and check delta
    const move_event2 = event.ZEvent{ .MouseMove = .{ .x = 150.0, .y = 250.0 } };
    InputManager.Update(move_event2);

    var delta = InputManager.GetMouseMoveDelta();
    try std.testing.expectEqual(@as(f32, 50.0), delta.x);
    try std.testing.expectEqual(@as(f32, 50.0), delta.y);

    // Move again and check new delta
    const move_event3 = event.ZEvent{ .MouseMove = .{ .x = 125.0, .y = 225.0 } };
    InputManager.Update(move_event3);

    delta = InputManager.GetMouseMoveDelta();
    try std.testing.expectEqual(@as(f32, -25.0), delta.x);
    try std.testing.expectEqual(@as(f32, -25.0), delta.y);

    // Clear should reset delta to zero
    InputManager.Clear();
    delta = InputManager.GetMouseMoveDelta();
    try std.testing.expectEqual(@as(f32, 0.0), delta.x);
    try std.testing.expectEqual(@as(f32, 0.0), delta.y);
}
