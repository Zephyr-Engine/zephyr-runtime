const std = @import("std");
const uuid = @import("../assets/uuid.zig");
const math = @import("../core/math.zig");

const AssetId = uuid.AssetId;
const Mat4 = math.Mat4;
const Quat = math.Quat;
const Vec3 = math.Vec3;

pub const TransformComponent = struct {
    position: Vec3 = Vec3.zero,
    rotation: Quat = Quat.identity,
    scale: Vec3 = Vec3.one,

    pub fn modelMatrix(self: *const TransformComponent) Mat4 {
        return Mat4.createTranslation(self.position)
            .mul(self.rotation.toMat4())
            .mul(Mat4.createScale(self.scale.x, self.scale.y, self.scale.z));
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
    mesh: AssetId,
    material: AssetId,
};

pub const CameraComponent = struct {
    fov: f32 = std.math.pi / 4.0,
    near: f32 = 0.1,
    far: f32 = 1000.0,

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
    yaw: f32 = 0,
    pitch: f32 = 0,
    look_sensitivity: f32 = 0.02,
    pan_sensitivity: f32 = 0.035,
    zoom_speed: f32 = 1.0,
};
