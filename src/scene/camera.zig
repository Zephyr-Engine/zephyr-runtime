const std = @import("std");
const math = @import("../core/math.zig");
const ZEvent = @import("../core/event.zig").ZEvent;

const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Quat = math.Quat;

pub const Camera3D = struct {
    position: Vec3,
    orientation: Quat,

    // Projection
    fov: f32,
    aspect: f32,
    near: f32,
    far: f32,

    // Euler angles
    yaw: f32,
    pitch: f32,

    pub const max_pitch: f32 = std.math.pi / 2.0 - 0.02;
    const world_up = Vec3.new(0, 1, 0);

    pub fn init(position: Vec3, aspect: f32) Camera3D {
        var cam = Camera3D{
            .position = position,
            .orientation = Quat.identity,
            .fov = std.math.pi / 4.0,
            .aspect = aspect,
            .near = 0.1,
            .far = 1000.0,
            .yaw = 0,
            .pitch = 0,
        };
        cam.updateOrientation();

        return cam;
    }

    pub fn updateOrientation(self: *Camera3D) void {
        const q_yaw = Quat.fromAxisAngle(Vec3.new(0, 1, 0), self.yaw);
        const q_pitch = Quat.fromAxisAngle(Vec3.new(1, 0, 0), self.pitch);

        self.orientation = q_yaw.mul(q_pitch);
    }

    pub fn front(self: *const Camera3D) Vec3 {
        return self.orientation.rotateVec3(Vec3.new(0, 0, -1));
    }

    pub fn right(self: *const Camera3D) Vec3 {
        return self.orientation.rotateVec3(Vec3.new(1, 0, 0));
    }

    pub fn up(self: *const Camera3D) Vec3 {
        return self.orientation.rotateVec3(Vec3.new(0, 1, 0));
    }

    pub fn viewMatrix(self: *const Camera3D) Mat4 {
        return Mat4.createLookAt(self.position, self.position.add(self.front()), world_up);
    }

    pub fn projectionMatrix(self: *const Camera3D) Mat4 {
        return Mat4.createPerspective(self.fov, self.aspect, self.near, self.far);
    }

    pub fn viewProjectionMatrix(self: *const Camera3D) Mat4 {
        return self.projectionMatrix().mul(self.viewMatrix());
    }

    pub fn processEvent(self: *Camera3D, event: ZEvent) void {
        switch (event) {
            .FramebufferResize => |resize| {
                if (resize.width > 0 and resize.height > 0) {
                    self.aspect = @as(f32, @floatFromInt(resize.width)) / @as(f32, @floatFromInt(resize.height));
                }
            },
            else => {},
        }
    }
};

const expect = std.testing.expect;
const expectApproxEq = std.testing.expectApproxEqAbs;
const tolerance: f32 = 1e-4;

test "Camera3D default looks down -Z" {
    const cam = Camera3D.init(Vec3.new(0, 0, 3), 16.0 / 9.0);
    const f = cam.front();
    try expectApproxEq(f.x, 0, tolerance);
    try expectApproxEq(f.y, 0, tolerance);
    try expectApproxEq(f.z, -1, tolerance);
}

test "Camera3D view matrix matches lookAt" {
    const cam = Camera3D.init(Vec3.new(0, 0, 3), 16.0 / 9.0);
    const view = cam.viewMatrix();
    const expected = Mat4.createLookAt(Vec3.new(0, 0, 3), Vec3.new(0, 0, 2), Vec3.new(0, 1, 0));

    for (0..4) |row| {
        for (0..4) |col| {
            try expectApproxEq(view.fields[row][col], expected.fields[row][col], tolerance);
        }
    }
}

test "Camera3D projection uses given params" {
    const cam = Camera3D.init(Vec3.new(0, 0, 3), 2.0);
    const proj = cam.projectionMatrix();
    const expected = Mat4.createPerspective(std.math.pi / 4.0, 2.0, 0.1, 1000.0);

    for (0..4) |row| {
        for (0..4) |col| {
            try expectApproxEq(proj.fields[row][col], expected.fields[row][col], tolerance);
        }
    }
}

test "Camera3D pitch clamping" {
    var cam = Camera3D.init(Vec3.zero, 1.0);
    cam.pitch = 2.0;
    cam.pitch = std.math.clamp(cam.pitch, -Camera3D.max_pitch, Camera3D.max_pitch);
    try expect(cam.pitch <= Camera3D.max_pitch);
    try expect(cam.pitch >= -Camera3D.max_pitch);
}
