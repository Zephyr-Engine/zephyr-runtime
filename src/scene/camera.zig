const std = @import("std");
const math = @import("zlm").as(f32);

const PI = std.math.pi;
const FRAC_PI_2 = std.math.pi / 2.0;

pub const Quat = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const IDENTITY = Quat{ .x = 0, .y = 0, .z = 0, .w = 1 };

    pub fn fromAxisAngle(axis: math.Vec3, angle: f32) Quat {
        const half_angle = angle / 2.0;
        const s = @sin(half_angle);
        return .{
            .x = axis.x * s,
            .y = axis.y * s,
            .z = axis.z * s,
            .w = @cos(half_angle),
        };
    }

    pub fn mul(self: Quat, other: Quat) Quat {
        return .{
            .x = self.w * other.x + self.x * other.w + self.y * other.z - self.z * other.y,
            .y = self.w * other.y - self.x * other.z + self.y * other.w + self.z * other.x,
            .z = self.w * other.z + self.x * other.y - self.y * other.x + self.z * other.w,
            .w = self.w * other.w - self.x * other.x - self.y * other.y - self.z * other.z,
        };
    }

    pub fn mulVec3(self: Quat, v: math.Vec3) math.Vec3 {
        const qv = math.Vec3.new(self.x, self.y, self.z);
        const uv = math.Vec3.cross(qv, v);
        const uuv = math.Vec3.cross(qv, uv);
        return v.add(uv.scale(2.0 * self.w)).add(uuv.scale(2.0));
    }

    pub fn normalize(self: Quat) Quat {
        const len = @sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w);
        return .{
            .x = self.x / len,
            .y = self.y / len,
            .z = self.z / len,
            .w = self.w / len,
        };
    }

    pub fn inverse(self: Quat) Quat {
        const len_sq = self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w;
        return .{
            .x = -self.x / len_sq,
            .y = -self.y / len_sq,
            .z = -self.z / len_sq,
            .w = self.w / len_sq,
        };
    }

    pub fn toMat4(self: Quat) math.Mat4 {
        const x2 = self.x * self.x;
        const y2 = self.y * self.y;
        const z2 = self.z * self.z;
        const xy = self.x * self.y;
        const xz = self.x * self.z;
        const yz = self.y * self.z;
        const wx = self.w * self.x;
        const wy = self.w * self.y;
        const wz = self.w * self.z;

        return math.Mat4.new(
            .{ 1.0 - 2.0 * (y2 + z2), 2.0 * (xy + wz), 2.0 * (xz - wy), 0.0 },
            .{ 2.0 * (xy - wz), 1.0 - 2.0 * (x2 + z2), 2.0 * (yz + wx), 0.0 },
            .{ 2.0 * (xz + wy), 2.0 * (yz - wx), 1.0 - 2.0 * (x2 + y2), 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        );
    }

    pub fn fromMat4(m: math.Mat4) Quat {
        const trace = m.fields[0][0] + m.fields[1][1] + m.fields[2][2];
        if (trace > 0.0) {
            const s = 0.5 / @sqrt(trace + 1.0);
            return .{
                .w = 0.25 / s,
                .x = (m.fields[2][1] - m.fields[1][2]) * s,
                .y = (m.fields[0][2] - m.fields[2][0]) * s,
                .z = (m.fields[1][0] - m.fields[0][1]) * s,
            };
        } else if (m.fields[0][0] > m.fields[1][1] and m.fields[0][0] > m.fields[2][2]) {
            const s = 2.0 * @sqrt(1.0 + m.fields[0][0] - m.fields[1][1] - m.fields[2][2]);
            return .{
                .w = (m.fields[2][1] - m.fields[1][2]) / s,
                .x = 0.25 * s,
                .y = (m.fields[0][1] + m.fields[1][0]) / s,
                .z = (m.fields[0][2] + m.fields[2][0]) / s,
            };
        } else if (m.fields[1][1] > m.fields[2][2]) {
            const s = 2.0 * @sqrt(1.0 + m.fields[1][1] - m.fields[0][0] - m.fields[2][2]);
            return .{
                .w = (m.fields[0][2] - m.fields[2][0]) / s,
                .x = (m.fields[0][1] + m.fields[1][0]) / s,
                .y = 0.25 * s,
                .z = (m.fields[1][2] + m.fields[2][1]) / s,
            };
        } else {
            const s = 2.0 * @sqrt(1.0 + m.fields[2][2] - m.fields[0][0] - m.fields[1][1]);
            return .{
                .w = (m.fields[1][0] - m.fields[0][1]) / s,
                .x = (m.fields[0][2] + m.fields[2][0]) / s,
                .y = (m.fields[1][2] + m.fields[2][1]) / s,
                .z = 0.25 * s,
            };
        }
    }
};

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
        const max_fov = PI - 0.1;
        self.fov = std.math.clamp(self.fov, min_fov, max_fov);
    }

    pub fn viewProjectionMatrix(self: *const Camera) math.Mat4 {
        return self.projectionMatrix().mul(self.viewMatrix());
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

    pub fn lookat(self: *const Camera) math.Mat4 {
        return self.projectionMatrix().mul(self.viewMatrix());
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
