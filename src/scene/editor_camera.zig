const std = @import("std");

const math = @import("../core/math.zig");
const Camera3D = @import("camera.zig").Camera3D;
const ZEvent = @import("../core/event.zig").ZEvent;
const Input = @import("../core/input.zig").InputManager;

const Vec3 = math.Vec3;

pub const EditorCamera = struct {
    camera: Camera3D,

    look_sensitivity: f32,
    pan_sensitivity: f32,
    zoom_speed: f32,

    pub fn init(position: Vec3, aspect: f32) EditorCamera {
        return .{
            .camera = Camera3D.init(position, aspect),
            .look_sensitivity = 0.02,
            .pan_sensitivity = 0.035,
            .zoom_speed = 1.0,
        };
    }

    pub fn update(self: *EditorCamera) void {
        const delta = Input.GetMouseMoveDelta();

        if (Input.IsButtonHeld(.Right)) {
            self.camera.yaw -= delta.x * self.look_sensitivity;
            self.camera.pitch -= delta.y * self.look_sensitivity;
            self.camera.pitch = std.math.clamp(
                self.camera.pitch,
                -Camera3D.max_pitch,
                Camera3D.max_pitch,
            );
            self.camera.updateOrientation();
        }

        if (Input.IsButtonHeld(.Left)) {
            const r = self.camera.right();
            const u = self.camera.up();
            self.camera.position = self.camera.position.sub(
                r.scale(delta.x * self.pan_sensitivity),
            );
            self.camera.position = self.camera.position.sub(
                u.scale(delta.y * self.pan_sensitivity),
            );
        }

        const scroll = Input.GetMouseMoveScroll();
        if (scroll.y != 0) {
            self.camera.position = self.camera.position.add(
                self.camera.front().scale(scroll.y * self.zoom_speed),
            );
        }
    }

    pub fn processEvent(self: *EditorCamera, event: ZEvent) void {
        self.camera.processEvent(event);
    }
};

test "EditorCamera forwards framebuffer resize events" {
    var editor = EditorCamera.init(Vec3.zero, 1.0);
    editor.processEvent(.{ .FramebufferResize = .{ .width = 1600, .height = 900 } });
    try std.testing.expectApproxEqAbs(@as(f32, 16.0 / 9.0), editor.camera.aspect, 0.0001);
}
