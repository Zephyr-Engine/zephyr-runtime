const std = @import("std");
const uuid = @import("../assets/uuid.zig");
const math = @import("../core/math.zig");

const AssetId = uuid.AssetId;
const Mat4 = math.Mat4;
const Quat = math.Quat;
const Vec3 = math.Vec3;

pub const TransformComponent = struct {
    rotation: Quat = Quat.identity,
    position: Vec3 = Vec3.zero,
    scale: Vec3 = Vec3.one,

    pub fn modelMatrix(self: *const TransformComponent) Mat4 {
        return Mat4.createScale(self.scale.x, self.scale.y, self.scale.z)
            .mul(self.rotation.toMat4())
            .mul(Mat4.createTranslation(self.position));
    }

    pub fn forward(self: *const TransformComponent) Vec3 {
        return self.rotation.rotateVec3(Vec3.new(0, 0, -1));
    }

    pub fn right(self: *const TransformComponent) Vec3 {
        return self.rotation.rotateVec3(Vec3.new(1, 0, 0));
    }

    pub fn up(self: *const TransformComponent) Vec3 {
        return self.rotation.rotateVec3(Vec3.new(0, 1, 0));
    }
};

pub const MeshRenderComponent = struct {
    material: AssetId,
    mesh: AssetId,
};

pub const CameraComponent = struct {
    fov: f32 = std.math.pi / 4.0,
    far: f32 = 1000.0,
    near: f32 = 0.1,

    pub fn projectionMatrix(self: *const CameraComponent, aspect: f32) Mat4 {
        return Mat4.createPerspective(self.fov, aspect, self.near, self.far);
    }

    pub fn viewMatrix(_: *const CameraComponent, transform: *const TransformComponent) Mat4 {
        return Mat4.createLookAt(
            transform.position,
            transform.position.add(transform.forward()),
            transform.up(),
        );
    }
};

pub const FlyCameraController = struct {
    look_sensitivity: f32 = 0.02,
    pan_sensitivity: f32 = 0.035,
    zoom_speed: f32 = 1.0,
    pitch: f32 = 0,
    yaw: f32 = 0,
};

const expectApproxEq = std.testing.expectApproxEqAbs;
const tolerance: f32 = 1e-5;

fn expectVec3(expected: Vec3, actual: Vec3) !void {
    try expectApproxEq(expected.x, actual.x, tolerance);
    try expectApproxEq(expected.y, actual.y, tolerance);
    try expectApproxEq(expected.z, actual.z, tolerance);
}

test "TransformComponent defaults to an identity transform" {
    const t = TransformComponent{};
    try expectVec3(Vec3.zero, t.position);
    try expectVec3(Vec3.one, t.scale);
    try std.testing.expectEqual(Quat.identity, t.rotation);
}

test "TransformComponent basis vectors with identity rotation" {
    const t = TransformComponent{};
    try expectVec3(Vec3.new(0, 0, -1), t.forward());
    try expectVec3(Vec3.new(1, 0, 0), t.right());
    try expectVec3(Vec3.new(0, 1, 0), t.up());
}

test "TransformComponent basis vectors follow rotation" {
    // 90° right-handed rotation about +Y: forward(-Z) -> -X, right(+X) -> -Z, up unchanged.
    const t = TransformComponent{
        .rotation = Quat.fromAxisAngle(Vec3.new(0, 1, 0), std.math.pi / 2.0),
    };
    try expectVec3(Vec3.new(-1, 0, 0), t.forward());
    try expectVec3(Vec3.new(0, 0, -1), t.right());
    try expectVec3(Vec3.new(0, 1, 0), t.up());
}

test "modelMatrix maps the local origin to the world position" {
    // Regression guard for the S·R·T composition order: rotation and scale must
    // leave the origin fixed so it lands exactly on `position`.
    const t = TransformComponent{
        .position = Vec3.new(10, -3, 5),
        .rotation = Quat.fromAxisAngle(Vec3.new(0, 0, 1), std.math.pi / 2.0),
        .scale = Vec3.new(2, 2, 2),
    };
    try expectVec3(t.position, Vec3.zero.transformPosition(t.modelMatrix()));
}

test "modelMatrix applies scale then rotation then translation" {
    const t = TransformComponent{
        .position = Vec3.new(10, 0, 0),
        .rotation = Quat.fromAxisAngle(Vec3.new(0, 0, 1), std.math.pi / 2.0),
        .scale = Vec3.new(2, 3, 4),
    };
    // (1,0,0) -> scale -> (2,0,0) -> rotate 90° about Z -> (0,2,0) -> translate -> (10,2,0).
    const transformed = Vec3.new(1, 0, 0).transformPosition(t.modelMatrix());
    try expectVec3(Vec3.new(10, 2, 0), transformed);
}

test "modelMatrix with identity transform is the identity matrix" {
    const t = TransformComponent{};
    const v = Vec3.new(3, -7, 2);
    try expectVec3(v, v.transformPosition(t.modelMatrix()));
}

test "CameraComponent defaults match a standard perspective setup" {
    const camera = CameraComponent{};
    try expectApproxEq(@as(f32, std.math.pi / 4.0), camera.fov, tolerance);
    try expectApproxEq(@as(f32, 0.1), camera.near, tolerance);
    try expectApproxEq(@as(f32, 1000.0), camera.far, tolerance);
}

test "CameraComponent projectionMatrix matches createPerspective for its aspect" {
    const camera = CameraComponent{ .fov = 1.0, .near = 0.5, .far = 100.0 };
    const projection = camera.projectionMatrix(1.5);
    const expected = Mat4.createPerspective(1.0, 1.5, 0.5, 100.0);
    for (0..4) |row| {
        for (0..4) |col| {
            try expectApproxEq(expected.fields[row][col], projection.fields[row][col], tolerance);
        }
    }
}

test "CameraComponent viewMatrix looks along the transform forward axis" {
    const camera = CameraComponent{};
    const transform = TransformComponent{ .position = Vec3.new(0, 0, 5) };
    const view = camera.viewMatrix(&transform);
    const expected = Mat4.createLookAt(
        transform.position,
        transform.position.add(transform.forward()),
        transform.up(),
    );
    for (0..4) |row| {
        for (0..4) |col| {
            try expectApproxEq(expected.fields[row][col], view.fields[row][col], tolerance);
        }
    }
}
