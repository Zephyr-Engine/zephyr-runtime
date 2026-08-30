const std = @import("std");

const zlm = @import("zlm").as(f32);

pub const Vec4 = zlm.Vec4;
pub const Vec3 = zlm.Vec3;
pub const Vec2 = zlm.Vec2;
pub const Mat4 = zlm.Mat4;
pub const Mat3 = zlm.Mat3;
pub const Mat2 = zlm.Mat2;

pub fn normalMatrix(self: Mat4) Mat3 {
    const m = self.fields;
    const a = m[0][0];
    const b = m[0][1];
    const c = m[0][2];
    const d = m[1][0];
    const e = m[1][1];
    const f = m[1][2];
    const g = m[2][0];
    const h = m[2][1];
    const i = m[2][2];

    const det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    std.debug.assert(det != 0);
    const inv_det = 1.0 / det;

    return .{ .fields = .{
        .{ (e * i - f * h) * inv_det, (f * g - d * i) * inv_det, (d * h - e * g) * inv_det },
        .{ (c * h - b * i) * inv_det, (a * i - c * g) * inv_det, (b * g - a * h) * inv_det },
        .{ (b * f - c * e) * inv_det, (c * d - a * f) * inv_det, (a * e - b * d) * inv_det },
    } };
}

pub const Quat = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 1,

    pub const identity = Quat{ .x = 0, .y = 0, .z = 0, .w = 1 };

    pub fn fromAxisAngle(axis: Vec3, angle: f32) Quat {
        const half = angle * 0.5;
        const s = @sin(half);
        const c = @cos(half);
        const n = axis.normalize();
        return .{
            .x = n.x * s,
            .y = n.y * s,
            .z = n.z * s,
            .w = c,
        };
    }

    pub fn fromEuler(yaw: f32, pitch: f32, roll: f32) Quat {
        const qy = fromAxisAngle(Vec3.new(0, 1, 0), yaw);
        const qx = fromAxisAngle(Vec3.new(1, 0, 0), pitch);
        const qz = fromAxisAngle(Vec3.new(0, 0, 1), roll);
        return qy.mul(qx).mul(qz);
    }

    pub fn mul(a: Quat, b: Quat) Quat {
        return .{
            .w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
            .x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            .y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
            .z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
        };
    }

    pub fn normalize(q: Quat) Quat {
        const len = @sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
        if (len < 1e-10) return identity;
        const inv = 1.0 / len;
        return .{
            .x = q.x * inv,
            .y = q.y * inv,
            .z = q.z * inv,
            .w = q.w * inv,
        };
    }

    pub fn conjugate(q: Quat) Quat {
        return .{ .x = -q.x, .y = -q.y, .z = -q.z, .w = q.w };
    }

    pub fn rotateVec3(q: Quat, v: Vec3) Vec3 {
        const qv = Quat{ .x = v.x, .y = v.y, .z = v.z, .w = 0 };
        const result = q.mul(qv).mul(q.conjugate());
        return Vec3.new(result.x, result.y, result.z);
    }

    pub fn toMat4(q: Quat) Mat4 {
        const xx = q.x * q.x;
        const yy = q.y * q.y;
        const zz = q.z * q.z;
        const xy = q.x * q.y;
        const xz = q.x * q.z;
        const yz = q.y * q.z;
        const wx = q.w * q.x;
        const wy = q.w * q.y;
        const wz = q.w * q.z;

        return .{ .fields = .{
            .{ 1 - 2 * (yy + zz), 2 * (xy + wz), 2 * (xz - wy), 0 },
            .{ 2 * (xy - wz), 1 - 2 * (xx + zz), 2 * (yz + wx), 0 },
            .{ 2 * (xz + wy), 2 * (yz - wx), 1 - 2 * (xx + yy), 0 },
            .{ 0, 0, 0, 1 },
        } };
    }

    pub fn slerp(a: Quat, b_in: Quat, t: f32) Quat {
        var b = b_in;
        var dot = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;

        if (dot < 0) {
            b = .{ .x = -b.x, .y = -b.y, .z = -b.z, .w = -b.w };
            dot = -dot;
        }

        if (dot > 0.9995) {
            return Quat.normalize(.{
                .x = a.x + t * (b.x - a.x),
                .y = a.y + t * (b.y - a.y),
                .z = a.z + t * (b.z - a.z),
                .w = a.w + t * (b.w - a.w),
            });
        }

        const theta = std.math.acos(dot);
        const sin_theta = @sin(theta);
        const wa = @sin((1 - t) * theta) / sin_theta;
        const wb = @sin(t * theta) / sin_theta;

        return .{
            .x = wa * a.x + wb * b.x,
            .y = wa * a.y + wb * b.y,
            .z = wa * a.z + wb * b.z,
            .w = wa * a.w + wb * b.w,
        };
    }
};

const expect = std.testing.expect;
const expectApproxEq = std.testing.expectApproxEqAbs;
const tolerance: f32 = 1e-5;

test "Quat identity rotation leaves vector unchanged" {
    const v = Vec3.new(1, 2, 3);
    const r = Quat.identity.rotateVec3(v);
    try expectApproxEq(r.x, 1, tolerance);
    try expectApproxEq(r.y, 2, tolerance);
    try expectApproxEq(r.z, 3, tolerance);
}

test "Quat 90° rotation around Y" {
    const q = Quat.fromAxisAngle(Vec3.new(0, 1, 0), std.math.pi / 2.0);
    const r = q.rotateVec3(Vec3.new(0, 0, -1));
    try expectApproxEq(r.x, -1, tolerance);
    try expectApproxEq(r.y, 0, tolerance);
    try expectApproxEq(r.z, 0, tolerance);
}

test "Quat 90° rotation around X" {
    const q = Quat.fromAxisAngle(Vec3.new(1, 0, 0), std.math.pi / 2.0);
    const r = q.rotateVec3(Vec3.new(0, 1, 0));
    try expectApproxEq(r.x, 0, tolerance);
    try expectApproxEq(r.y, 0, tolerance);
    try expectApproxEq(r.z, 1, tolerance);
}

test "Quat 90° rotation around Z" {
    const q = Quat.fromAxisAngle(Vec3.new(0, 0, 1), std.math.pi / 2.0);
    const r = q.rotateVec3(Vec3.new(1, 0, 0));
    try expectApproxEq(r.x, 0, tolerance);
    try expectApproxEq(r.y, 1, tolerance);
    try expectApproxEq(r.z, 0, tolerance);
}

test "Quat mul is associative" {
    const a = Quat.fromAxisAngle(Vec3.new(1, 0, 0), 0.3);
    const b = Quat.fromAxisAngle(Vec3.new(0, 1, 0), 0.7);
    const c = Quat.fromAxisAngle(Vec3.new(0, 0, 1), 1.1);

    const ab_c = a.mul(b).mul(c);
    const a_bc = a.mul(b.mul(c));

    try expectApproxEq(ab_c.x, a_bc.x, tolerance);
    try expectApproxEq(ab_c.y, a_bc.y, tolerance);
    try expectApproxEq(ab_c.z, a_bc.z, tolerance);
    try expectApproxEq(ab_c.w, a_bc.w, tolerance);
}

test "Quat normalize" {
    const q = Quat{ .x = 1, .y = 2, .z = 3, .w = 4 };
    const n = Quat.normalize(q);
    const len = @sqrt(n.x * n.x + n.y * n.y + n.z * n.z + n.w * n.w);
    try expectApproxEq(len, 1.0, tolerance);
}

test "Quat toMat4 matches createAngleAxis for Y rotation" {
    const angle: f32 = 1.2;
    const axis = Vec3.new(0, 1, 0);
    const q = Quat.fromAxisAngle(axis, angle);
    const qmat = q.toMat4();
    const amat = Mat4.createAngleAxis(axis, angle);

    for (0..4) |row| {
        for (0..4) |col| {
            try expectApproxEq(qmat.fields[row][col], amat.fields[row][col], tolerance);
        }
    }
}

test "Quat toMat4 matches createAngleAxis for arbitrary axis" {
    const angle: f32 = 0.8;
    const axis = Vec3.new(1, 1, 1);
    const q = Quat.fromAxisAngle(axis, angle);
    const qmat = q.toMat4();
    const amat = Mat4.createAngleAxis(axis, angle);

    for (0..4) |row| {
        for (0..4) |col| {
            try expectApproxEq(qmat.fields[row][col], amat.fields[row][col], tolerance);
        }
    }
}

test "Quat slerp endpoints" {
    const a = Quat.fromAxisAngle(Vec3.new(0, 1, 0), 0.0);
    const b = Quat.fromAxisAngle(Vec3.new(0, 1, 0), std.math.pi / 2.0);

    const s0 = Quat.slerp(a, b, 0.0);
    try expectApproxEq(s0.x, a.x, tolerance);
    try expectApproxEq(s0.y, a.y, tolerance);
    try expectApproxEq(s0.z, a.z, tolerance);
    try expectApproxEq(s0.w, a.w, tolerance);

    const s1 = Quat.slerp(a, b, 1.0);
    try expectApproxEq(s1.x, b.x, tolerance);
    try expectApproxEq(s1.y, b.y, tolerance);
    try expectApproxEq(s1.z, b.z, tolerance);
    try expectApproxEq(s1.w, b.w, tolerance);
}

test "Quat rotateVec3 matches toMat4 transform" {
    const q = Quat.fromEuler(0.5, 0.3, 0.0);
    const v = Vec3.new(1, 0, -1);
    const r1 = q.rotateVec3(v);
    const m = q.toMat4();
    const r2 = v.transformDirection(m);
    try expectApproxEq(r1.x, r2.x, tolerance);
    try expectApproxEq(r1.y, r2.y, tolerance);
    try expectApproxEq(r1.z, r2.z, tolerance);
}
