const std = @import("std");
const math = @import("zlm").as(f32);

const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Quat = @import("../core/math.zig").Quat;
const AssetHandle = @import("manager.zig").AssetHandle;

pub const Transform = struct {
    position: Vec3 = Vec3.zero,
    rotation: Quat = Quat.identity,
    scale: Vec3 = Vec3.new(1, 1, 1),
    parent: ?AssetHandle = null,
    children: std.ArrayListUnmanaged(AssetHandle) = .{},

    pub const default = Transform{};

    pub fn fromPosition(pos: Vec3) Transform {
        return .{ .position = pos };
    }

    pub fn localMatrix(self: Transform) Mat4 {
        const t = Mat4.createTranslation(self.position);
        const r = self.rotation.toMat4();
        const s = Mat4.createScale(self.scale.x, self.scale.y, self.scale.z);
        return t.mul(r.mul(s));
    }

    pub fn forward(self: Transform) Vec3 {
        return self.rotation.mulVec3(Vec3.new(0, 0, -1));
    }

    pub fn right(self: Transform) Vec3 {
        return self.rotation.mulVec3(Vec3.new(1, 0, 0));
    }

    pub fn up(self: Transform) Vec3 {
        return self.rotation.mulVec3(Vec3.new(0, 1, 0));
    }

    pub fn translate(self: *Transform, delta: Vec3) void {
        self.position = self.position.add(delta);
    }

    pub fn rotate(self: *Transform, axis: Vec3, angle: f32) void {
        const q = Quat.fromAxisAngle(axis, angle);
        self.rotation = q.mul(self.rotation).normalize();
    }

    pub fn deinit(self: *Transform, allocator: std.mem.Allocator) void {
        self.children.deinit(allocator);
    }
};

const testing = std.testing;

fn expectApproxEq(expected: f32, actual: f32) !void {
    try testing.expectApproxEqAbs(expected, actual, 1e-5);
}

test "default is identity transform" {
    const t = Transform.default;
    try testing.expectEqual(Vec3.zero, t.position);
    try testing.expectEqual(Quat.identity, t.rotation);
    try testing.expectEqual(Vec3.new(1, 1, 1), t.scale);
    try testing.expectEqual(@as(?AssetHandle, null), t.parent);
    try testing.expectEqual(@as(usize, 0), t.children.items.len);
}

test "fromPosition sets position only" {
    const t = Transform.fromPosition(Vec3.new(3, 4, 5));
    try testing.expectEqual(Vec3.new(3, 4, 5), t.position);
    try testing.expectEqual(Quat.identity, t.rotation);
    try testing.expectEqual(Vec3.new(1, 1, 1), t.scale);
}

test "localMatrix identity" {
    const t = Transform.default;
    const m = t.localMatrix();
    // Should be identity matrix
    for (0..4) |row| {
        for (0..4) |col| {
            const expected: f32 = if (row == col) 1.0 else 0.0;
            try expectApproxEq(expected, m.fields[row][col]);
        }
    }
}

test "localMatrix with TRS" {
    const t = Transform{
        .position = Vec3.new(1, 2, 3),
        .rotation = Quat.identity,
        .scale = Vec3.new(2, 2, 2),
    };
    const m = t.localMatrix();
    // Scale should be 2 on diagonal
    try expectApproxEq(2.0, m.fields[0][0]);
    try expectApproxEq(2.0, m.fields[1][1]);
    try expectApproxEq(2.0, m.fields[2][2]);
    // Translation row is scaled by T * R * S composition
    try expectApproxEq(2.0, m.fields[3][0]);
    try expectApproxEq(4.0, m.fields[3][1]);
    try expectApproxEq(6.0, m.fields[3][2]);
}

test "direction vectors identity" {
    const t = Transform.default;
    const fwd = t.forward();
    const rt = t.right();
    const u = t.up();

    try expectApproxEq(0, fwd.x);
    try expectApproxEq(0, fwd.y);
    try expectApproxEq(-1, fwd.z);

    try expectApproxEq(1, rt.x);
    try expectApproxEq(0, rt.y);
    try expectApproxEq(0, rt.z);

    try expectApproxEq(0, u.x);
    try expectApproxEq(1, u.y);
    try expectApproxEq(0, u.z);
}

test "translate mutator" {
    var t = Transform.default;
    t.translate(Vec3.new(1, 2, 3));
    try expectApproxEq(1, t.position.x);
    try expectApproxEq(2, t.position.y);
    try expectApproxEq(3, t.position.z);

    t.translate(Vec3.new(-1, 0, 1));
    try expectApproxEq(0, t.position.x);
    try expectApproxEq(2, t.position.y);
    try expectApproxEq(4, t.position.z);
}

test "rotate mutator" {
    var t = Transform.default;
    t.rotate(Vec3.new(0, 1, 0), std.math.pi / 2.0);

    // After 90 degree rotation around Y, forward (0,0,-1) should point along -X
    const fwd = t.forward();
    try expectApproxEq(-1, fwd.x);
    try expectApproxEq(0, fwd.y);
    try expectApproxEq(0, fwd.z);
}
