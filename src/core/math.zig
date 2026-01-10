const std = @import("std");
const math = @import("zlm").as(f32);

pub const Vec3 = math.Vec3;
pub const Vec2 = math.Vec2;
pub const Mat2 = math.Mat2;
pub const Mat3 = math.Mat3;
pub const Mat4 = math.Mat4;

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
