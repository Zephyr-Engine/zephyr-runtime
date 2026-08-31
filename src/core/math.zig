const std = @import("std");

const zlm = @import("zlm").as(f32);

pub const Vec4 = zlm.Vec4;
pub const Vec3 = zlm.Vec3;
pub const Vec2 = zlm.Vec2;
pub const Mat4 = zlm.Mat4;
pub const Mat3 = zlm.Mat3;
pub const Mat2 = zlm.Mat2;

pub const epsilon: f32 = 1e-8;

pub fn normalMatrix(self: Mat4) Mat3 {
    const m = self.fields;
    const scale = @max(
        @max(@max(@abs(m[0][0]), @abs(m[0][1])), @abs(m[0][2])),
        @max(
            @max(@max(@abs(m[1][0]), @abs(m[1][1])), @abs(m[1][2])),
            @max(@max(@abs(m[2][0]), @abs(m[2][1])), @abs(m[2][2])),
        ),
    );
    if (scale == 0) {
        return .{ .fields = .{
            .{ 1, 0, 0 },
            .{ 0, 1, 0 },
            .{ 0, 0, 1 },
        } };
    }

    // Compute the determinant after scaling the linear part into a stable
    // range. This keeps the singularity check relative to the matrix's
    // magnitude, so small but invertible transforms are not rejected.
    const a = m[0][0] / scale;
    const b = m[0][1] / scale;
    const c = m[0][2] / scale;
    const d = m[1][0] / scale;
    const e = m[1][1] / scale;
    const f = m[1][2] / scale;
    const g = m[2][0] / scale;
    const h = m[2][1] / scale;
    const i = m[2][2] / scale;

    const det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    if (@abs(det) <= epsilon) {
        return .{ .fields = .{
            .{ 1, 0, 0 },
            .{ 0, 1, 0 },
            .{ 0, 0, 1 },
        } };
    }

    const inv_det = 1.0 / (det * scale);
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

fn expectMat3ApproxEq(actual: Mat3, expected: [3][3]f32, tol: f32) !void {
    for (0..3) |row| {
        for (0..3) |col| {
            try expectApproxEq(actual.fields[row][col], expected[row][col], tol);
        }
    }
}

fn expectQuatApproxEq(actual: Quat, expected: Quat, tol: f32) !void {
    try expectApproxEq(actual.x, expected.x, tol);
    try expectApproxEq(actual.y, expected.y, tol);
    try expectApproxEq(actual.z, expected.z, tol);
    try expectApproxEq(actual.w, expected.w, tol);
}

fn expectVec3ApproxEq(actual: Vec3, expected: Vec3, tol: f32) !void {
    try expectApproxEq(actual.x, expected.x, tol);
    try expectApproxEq(actual.y, expected.y, tol);
    try expectApproxEq(actual.z, expected.z, tol);
}

fn quatLength(q: Quat) f32 {
    return @sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
}

test "normalMatrix returns identity for identity and translation transforms" {
    try expectMat3ApproxEq(normalMatrix(Mat4.identity), .{
        .{ 1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 0, 0, 1 },
    }, tolerance);

    try expectMat3ApproxEq(normalMatrix(Mat4.createTranslationXYZ(4, -2, 7)), .{
        .{ 1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 0, 0, 1 },
    }, tolerance);
}

test "normalMatrix computes inverse transpose for non-uniform and reflected scales" {
    try expectMat3ApproxEq(normalMatrix(Mat4.createScale(2, 4, -5)), .{
        .{ 0.5, 0, 0 },
        .{ 0, 0.25, 0 },
        .{ 0, 0, -0.2 },
    }, tolerance);
}

test "normalMatrix computes inverse transpose for a general linear transform" {
    const transform = Mat4{ .fields = .{
        .{ 1, 2, 3, 0 },
        .{ 0, 1, 4, 0 },
        .{ 5, 6, 0, 0 },
        .{ 8, 9, 10, 1 },
    } };

    try expectMat3ApproxEq(normalMatrix(transform), .{
        .{ -24, 20, -5 },
        .{ 18, -15, 4 },
        .{ 5, -4, 1 },
    }, 0.0001);
}

test "normalMatrix preserves invertible small-scale transforms" {
    const transform = Mat4.createScale(0.001, 0.002, 0.003);
    const normal = normalMatrix(transform);

    try expectApproxEq(normal.fields[0][0], 1000.0, 0.001);
    try expectApproxEq(normal.fields[1][1], 500.0, 0.001);
    try expectApproxEq(normal.fields[2][2], 1000.0 / 3.0, 0.001);
    try expectApproxEq(normal.fields[0][1], 0.0, tolerance);
    try expectApproxEq(normal.fields[0][2], 0.0, tolerance);
    try expectApproxEq(normal.fields[1][0], 0.0, tolerance);
    try expectApproxEq(normal.fields[1][2], 0.0, tolerance);
    try expectApproxEq(normal.fields[2][0], 0.0, tolerance);
    try expectApproxEq(normal.fields[2][1], 0.0, tolerance);
}

test "normalMatrix remains finite for very large and very small uniform scales" {
    const large = normalMatrix(Mat4.createUniformScale(1e20));
    const small = normalMatrix(Mat4.createUniformScale(1e-20));

    for (0..3) |index| {
        try expect(std.math.isFinite(large.fields[index][index]));
        try std.testing.expectApproxEqRel(@as(f32, 1e-20), large.fields[index][index], tolerance);
        try expect(std.math.isFinite(small.fields[index][index]));
        try std.testing.expectApproxEqRel(@as(f32, 1e20), small.fields[index][index], tolerance);
    }
}

test "normalMatrix falls back to identity for singular transforms" {
    const zero_scale = normalMatrix(Mat4.createScale(0, 0, 0));
    try expectMat3ApproxEq(zero_scale, .{
        .{ 1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 0, 0, 1 },
    }, tolerance);

    const dependent_rows = Mat4{ .fields = .{
        .{ 1, 2, 3, 0 },
        .{ 2, 4, 6, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 0, 1 },
    } };
    try expectMat3ApproxEq(normalMatrix(dependent_rows), .{
        .{ 1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 0, 0, 1 },
    }, tolerance);
}

test "Quat default value is identity" {
    try std.testing.expectEqual(Quat.identity, Quat{});
}

test "Quat fromAxisAngle normalizes its axis" {
    const angle: f32 = std.math.pi / 3.0;
    const q = Quat.fromAxisAngle(Vec3.new(0, 5, 0), angle);

    try expectQuatApproxEq(q, .{
        .x = 0,
        .y = @sin(angle / 2.0),
        .z = 0,
        .w = @cos(angle / 2.0),
    }, tolerance);
}

test "Quat fromAxisAngle with zero angle returns identity" {
    try expectQuatApproxEq(
        Quat.fromAxisAngle(Vec3.new(2, -3, 4), 0),
        Quat.identity,
        tolerance,
    );
}

test "Quat fromEuler matches its documented yaw pitch roll composition" {
    const yaw: f32 = 0.4;
    const pitch: f32 = -0.7;
    const roll: f32 = 1.1;
    const q = Quat.fromEuler(yaw, pitch, roll);
    const expected = Quat.fromAxisAngle(Vec3.new(0, 1, 0), yaw)
        .mul(Quat.fromAxisAngle(Vec3.new(1, 0, 0), pitch))
        .mul(Quat.fromAxisAngle(Vec3.new(0, 0, 1), roll));

    try expectQuatApproxEq(q, expected, tolerance);

    const v = Vec3.new(0.3, -0.4, 0.8);
    const rolled = Quat.fromAxisAngle(Vec3.new(0, 0, 1), roll).rotateVec3(v);
    const pitched = Quat.fromAxisAngle(Vec3.new(1, 0, 0), pitch).rotateVec3(rolled);
    const yawed = Quat.fromAxisAngle(Vec3.new(0, 1, 0), yaw).rotateVec3(pitched);
    try expectVec3ApproxEq(q.rotateVec3(v), yawed, tolerance);
}

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

test "Quat identity is the left and right multiplication identity" {
    const q = Quat.fromEuler(0.2, -0.4, 0.8);
    try expectQuatApproxEq(Quat.identity.mul(q), q, tolerance);
    try expectQuatApproxEq(q.mul(Quat.identity), q, tolerance);
}

test "Quat multiplication composes rotations" {
    const x_rotation = Quat.fromAxisAngle(Vec3.new(1, 0, 0), 0.6);
    const y_rotation = Quat.fromAxisAngle(Vec3.new(0, 1, 0), -0.9);
    const v = Vec3.new(1, 2, 3);

    const composed = y_rotation.mul(x_rotation).rotateVec3(v);
    const sequential = y_rotation.rotateVec3(x_rotation.rotateVec3(v));
    try expectVec3ApproxEq(composed, sequential, tolerance);
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

test "Quat normalize preserves direction and handles near-zero input" {
    const q = Quat{ .x = 2, .y = -4, .z = 6, .w = -8 };
    const n = q.normalize();
    const inverse_length = 1.0 / @sqrt(@as(f32, 120));
    try expectQuatApproxEq(n, .{
        .x = 2 * inverse_length,
        .y = -4 * inverse_length,
        .z = 6 * inverse_length,
        .w = -8 * inverse_length,
    }, tolerance);
    try expectQuatApproxEq((Quat{ .x = 1e-12, .w = 1e-12 }).normalize(), Quat.identity, tolerance);
}

test "Quat conjugate negates the vector part and inverts unit rotations" {
    const q = Quat.fromEuler(0.2, -0.5, 0.7);
    try expectQuatApproxEq(q.conjugate(), .{
        .x = -q.x,
        .y = -q.y,
        .z = -q.z,
        .w = q.w,
    }, tolerance);
    try expectQuatApproxEq(q.mul(q.conjugate()), Quat.identity, tolerance);

    const v = Vec3.new(-2, 0.5, 4);
    try expectVec3ApproxEq(q.conjugate().rotateVec3(q.rotateVec3(v)), v, tolerance);
}

test "Quat rotateVec3 preserves vector length" {
    const q = Quat.fromEuler(0.8, -1.2, 0.3);
    const v = Vec3.new(2, -3, 6);
    const rotated = q.rotateVec3(v);
    try expectApproxEq(rotated.length(), v.length(), tolerance);
}

test "Quat identity converts to the identity matrix" {
    const matrix = Quat.identity.toMat4();
    for (0..4) |row| {
        for (0..4) |col| {
            const expected: f32 = if (row == col) 1 else 0;
            try expectApproxEq(matrix.fields[row][col], expected, tolerance);
        }
    }
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

test "Quat slerp midpoint follows constant angular interpolation" {
    const start = Quat.identity;
    const end = Quat.fromAxisAngle(Vec3.new(0, 1, 0), std.math.pi / 2.0);
    const midpoint = Quat.slerp(start, end, 0.5);
    const expected = Quat.fromAxisAngle(Vec3.new(0, 1, 0), std.math.pi / 4.0);

    try expectQuatApproxEq(midpoint, expected, tolerance);
    try expectApproxEq(quatLength(midpoint), 1.0, tolerance);
}

test "Quat slerp chooses the shortest path for opposite quaternion signs" {
    const end = Quat.fromAxisAngle(Vec3.new(0, 1, 0), std.math.pi / 2.0);
    const negated_end = Quat{ .x = -end.x, .y = -end.y, .z = -end.z, .w = -end.w };
    const midpoint = Quat.slerp(Quat.identity, negated_end, 0.5);
    const expected = Quat.fromAxisAngle(Vec3.new(0, 1, 0), std.math.pi / 4.0);

    try expectVec3ApproxEq(
        midpoint.rotateVec3(Vec3.new(0, 0, -1)),
        expected.rotateVec3(Vec3.new(0, 0, -1)),
        tolerance,
    );
    try expectApproxEq(quatLength(midpoint), 1.0, tolerance);
}

test "Quat slerp normalizes the near-linear interpolation branch" {
    const end = Quat.fromAxisAngle(Vec3.new(0, 0, 1), 0.001);
    const midpoint = Quat.slerp(Quat.identity, end, 0.5);
    const expected = Quat.fromAxisAngle(Vec3.new(0, 0, 1), 0.0005);

    try expectQuatApproxEq(midpoint, expected, tolerance);
    try expectApproxEq(quatLength(midpoint), 1.0, tolerance);
}

test "Quat slerp handles equivalent quaternions with opposite signs" {
    const opposite_identity = Quat{ .w = -1 };
    const interpolated = Quat.slerp(Quat.identity, opposite_identity, 0.37);
    try expectQuatApproxEq(interpolated, Quat.identity, tolerance);
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
