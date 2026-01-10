const std = @import("std");
const math = @import("../core/math.zig");
const Quat = math.Quat;

const FRAC_PI_2 = std.math.pi / 2.0;

pub const Camera = struct {
    position: math.Vec3,
    orientation: Quat,
    fov: f32,
    aspect_ratio: f32,
    near_plane: f32,
    far_plane: f32,
    is_active: bool,
    yaw: f32,
    pitch: f32,

    pub fn new(
        position: math.Vec3,
        fov: f32,
        aspect_ratio: f32,
        near_plane: f32,
        far_plane: f32,
        is_active: bool,
    ) Camera {
        return .{
            .position = position,
            .orientation = Quat.IDENTITY,
            .fov = fov,
            .aspect_ratio = aspect_ratio,
            .near_plane = near_plane,
            .far_plane = far_plane,
            .is_active = is_active,
            .yaw = 0.0,
            .pitch = 0.0,
        };
    }

    pub fn fpsLook(self: *Camera, mouse_delta_x: f32, mouse_delta_y: f32, sensitivity: f32) void {
        self.yaw += -mouse_delta_x * sensitivity;
        self.pitch += -mouse_delta_y * sensitivity;

        const max_pitch = FRAC_PI_2 - 0.01;
        self.pitch = std.math.clamp(self.pitch, -max_pitch, max_pitch);

        const yaw_q = Quat.fromAxisAngle(math.Vec3.new(0, 1, 0), self.yaw);
        const pitch_q = Quat.fromAxisAngle(math.Vec3.new(1, 0, 0), self.pitch);

        self.orientation = yaw_q.mul(pitch_q);
    }

    pub fn pan(self: *Camera, delta_x: f32, delta_y: f32, sensitivity: f32) void {
        const right_vec = self.right();
        const up_vec = self.up();

        self.position = self.position.add(right_vec.scale(delta_x * sensitivity));
        self.position = self.position.add(up_vec.scale(-delta_y * sensitivity));
    }

    pub fn zoom(self: *Camera, delta: f32, sensitivity: f32) void {
        self.fov -= delta * sensitivity;

        const min_fov = 0.1;
        const max_fov = std.math.pi - 0.1;
        self.fov = std.math.clamp(self.fov, min_fov, max_fov);
    }

    pub fn viewProjectionMatrix(self: *const Camera) math.Mat4 {
        return self.viewMatrix().mul(self.projectionMatrix());
    }

    pub fn lookAt(self: *Camera, target: math.Vec3, up_vec: math.Vec3) void {
        const forward_vec = math.Vec3.normalize(target.sub(self.position));
        const right_vec = math.Vec3.normalize(math.Vec3.cross(forward_vec, math.Vec3.normalize(up_vec)));
        const camera_up = math.Vec3.cross(right_vec, forward_vec);

        const look_matrix = math.Mat4.createLookAt(math.Vec3.new(0, 0, 0), forward_vec, camera_up);
        self.orientation = Quat.fromMat4(look_matrix.invert().?).normalize();
    }

    pub fn viewMatrix(self: *const Camera) math.Mat4 {
        const forward_vec = self.forward();
        const up_vec = self.up();
        return math.Mat4.createLookAt(self.position, self.position.add(forward_vec), up_vec);
    }

    pub fn projectionMatrix(self: *const Camera) math.Mat4 {
        return math.Mat4.createPerspective(self.fov, self.aspect_ratio, self.near_plane, self.far_plane);
    }

    pub fn setPosition(self: *Camera, position: math.Vec3) void {
        self.position = position;
    }

    pub fn setOrientation(self: *Camera, orientation: Quat) void {
        self.orientation = orientation.normalize();
    }

    pub fn setActive(self: *Camera, active: bool) void {
        self.is_active = active;
    }

    pub fn setAspectRatio(self: *Camera, aspect_ratio: f32) void {
        self.aspect_ratio = aspect_ratio;
    }

    fn forward(self: *const Camera) math.Vec3 {
        return self.orientation.mulVec3(math.Vec3.new(0, 0, -1));
    }

    fn right(self: *const Camera) math.Vec3 {
        return self.orientation.mulVec3(math.Vec3.new(1, 0, 0));
    }

    fn up(self: *const Camera) math.Vec3 {
        return self.orientation.mulVec3(math.Vec3.new(0, 1, 0));
    }
};
