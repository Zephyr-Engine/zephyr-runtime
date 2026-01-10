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

test "Camera.new creates camera with default values" {
    const camera = Camera.new(
        math.Vec3.new(0, 0, 5),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    try std.testing.expectEqual(math.Vec3.new(0, 0, 5), camera.position);
    try std.testing.expectEqual(Quat.IDENTITY, camera.orientation);
    try std.testing.expectApproxEqAbs(std.math.pi / 4.0, camera.fov, 0.001);
    try std.testing.expectApproxEqAbs(16.0 / 9.0, camera.aspect_ratio, 0.001);
    try std.testing.expectApproxEqAbs(0.1, camera.near_plane, 0.001);
    try std.testing.expectApproxEqAbs(100.0, camera.far_plane, 0.001);
    try std.testing.expect(camera.is_active);
    try std.testing.expectApproxEqAbs(0.0, camera.yaw, 0.001);
    try std.testing.expectApproxEqAbs(0.0, camera.pitch, 0.001);
}

test "Camera.fpsLook updates orientation" {
    var camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    camera.fpsLook(0.1, 0.1, 1.0);

    try std.testing.expectApproxEqAbs(-0.1, camera.yaw, 0.001);
    try std.testing.expectApproxEqAbs(-0.1, camera.pitch, 0.001);
    try std.testing.expect(camera.orientation.x != 0.0 or camera.orientation.y != 0.0 or camera.orientation.z != 0.0 or camera.orientation.w != 1.0);
}

test "Camera.fpsLook clamps pitch" {
    var camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const max_pitch = FRAC_PI_2 - 0.01;
    camera.fpsLook(0.0, -10.0, 1.0);
    try std.testing.expectApproxEqAbs(max_pitch, camera.pitch, 0.001);

    camera.fpsLook(0.0, 20.0, 1.0);
    try std.testing.expectApproxEqAbs(-max_pitch, camera.pitch, 0.001);
}

test "Camera.pan moves camera position" {
    var camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const initial_pos = camera.position;
    camera.pan(1.0, 1.0, 0.1);

    try std.testing.expect(!math.Vec3.eql(initial_pos, camera.position));
}

test "Camera.zoom adjusts fov" {
    var camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const initial_fov = camera.fov;
    camera.zoom(1.0, 0.1);

    try std.testing.expect(camera.fov < initial_fov);
}

test "Camera.zoom clamps fov" {
    var camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    camera.zoom(-100.0, 1.0);
    const max_fov = std.math.pi - 0.1;
    try std.testing.expectApproxEqAbs(max_fov, camera.fov, 0.001);

    camera.zoom(100.0, 1.0);
    const min_fov = 0.1;
    try std.testing.expectApproxEqAbs(min_fov, camera.fov, 0.001);
}

test "Camera.setPosition updates position" {
    var camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const new_pos = math.Vec3.new(1, 2, 3);
    camera.setPosition(new_pos);

    try std.testing.expectEqual(new_pos, camera.position);
}

test "Camera.setOrientation updates and normalizes orientation" {
    var camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const new_quat = Quat{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 0.5 };
    camera.setOrientation(new_quat);

    const len = @sqrt(camera.orientation.x * camera.orientation.x +
        camera.orientation.y * camera.orientation.y +
        camera.orientation.z * camera.orientation.z +
        camera.orientation.w * camera.orientation.w);

    try std.testing.expectApproxEqAbs(1.0, len, 0.001);
}

test "Camera.setActive updates active state" {
    var camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    camera.setActive(false);
    try std.testing.expect(!camera.is_active);

    camera.setActive(true);
    try std.testing.expect(camera.is_active);
}

test "Camera.setAspectRatio updates aspect ratio" {
    var camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    camera.setAspectRatio(4.0 / 3.0);
    try std.testing.expectApproxEqAbs(4.0 / 3.0, camera.aspect_ratio, 0.001);
}

test "Camera.forward returns correct direction vector" {
    const camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const forward_vec = camera.forward();
    const expected = math.Vec3.new(0, 0, -1);

    try std.testing.expectApproxEqAbs(expected.x, forward_vec.x, 0.001);
    try std.testing.expectApproxEqAbs(expected.y, forward_vec.y, 0.001);
    try std.testing.expectApproxEqAbs(expected.z, forward_vec.z, 0.001);
}

test "Camera.right returns correct direction vector" {
    const camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const right_vec = camera.right();
    const expected = math.Vec3.new(1, 0, 0);

    try std.testing.expectApproxEqAbs(expected.x, right_vec.x, 0.001);
    try std.testing.expectApproxEqAbs(expected.y, right_vec.y, 0.001);
    try std.testing.expectApproxEqAbs(expected.z, right_vec.z, 0.001);
}

test "Camera.up returns correct direction vector" {
    const camera = Camera.new(
        math.Vec3.new(0, 0, 0),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const up_vec = camera.up();
    const expected = math.Vec3.new(0, 1, 0);

    try std.testing.expectApproxEqAbs(expected.x, up_vec.x, 0.001);
    try std.testing.expectApproxEqAbs(expected.y, up_vec.y, 0.001);
    try std.testing.expectApproxEqAbs(expected.z, up_vec.z, 0.001);
}

test "Camera.lookAt points camera at target" {
    var camera = Camera.new(
        math.Vec3.new(5, 5, 5),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const initial_orientation = camera.orientation;
    const target = math.Vec3.new(0, 0, 0);
    camera.lookAt(target, math.Vec3.new(0, 1, 0));

    const orientation_changed = camera.orientation.x != initial_orientation.x or
        camera.orientation.y != initial_orientation.y or
        camera.orientation.z != initial_orientation.z or
        camera.orientation.w != initial_orientation.w;

    try std.testing.expect(orientation_changed);
}

test "Camera.viewMatrix returns valid matrix" {
    const camera = Camera.new(
        math.Vec3.new(0, 0, 5),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const view_mat = camera.viewMatrix();
    try std.testing.expect(view_mat.fields[0][0] != 0.0 or view_mat.fields[1][1] != 0.0 or view_mat.fields[2][2] != 0.0);
}

test "Camera.projectionMatrix returns valid matrix" {
    const camera = Camera.new(
        math.Vec3.new(0, 0, 5),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const proj_mat = camera.projectionMatrix();
    try std.testing.expect(proj_mat.fields[0][0] != 0.0 or proj_mat.fields[1][1] != 0.0 or proj_mat.fields[2][2] != 0.0);
}

test "Camera.viewProjectionMatrix returns valid matrix" {
    const camera = Camera.new(
        math.Vec3.new(0, 0, 5),
        std.math.pi / 4.0,
        16.0 / 9.0,
        0.1,
        100.0,
        true,
    );

    const vp_mat = camera.viewProjectionMatrix();
    try std.testing.expect(vp_mat.fields[0][0] != 0.0 or vp_mat.fields[1][1] != 0.0 or vp_mat.fields[2][2] != 0.0);
}
