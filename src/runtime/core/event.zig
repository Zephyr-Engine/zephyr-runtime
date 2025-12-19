pub const MouseButton = enum {
    Left,
    Right,
};

pub const ZEvent = union(enum) {
    WindowClose,
    WindowResize: struct { width: u32, height: u32 },
    KeyPressed: c_int,
    KeyReleased: c_int,
    KeyRepeated: c_int,
    MouseScroll: struct { x: f64, y: f64 },
    MouseMove: struct { x: f64, y: f64 },
    MousePressed: MouseButton,
    MouseReleased: MouseButton,
};

pub const ZEventCallback = *const fn (ZEvent) void;
