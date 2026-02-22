const Vec3 = @import("../core/math.zig").Vec3;

pub const LightKind = enum(i32) {
    directional = 0,
    point = 1,
    spot = 2,
};

pub const Light = struct {
    kind: LightKind = .point,

    // shared
    position: Vec3,
    ambient: Vec3,
    diffuse: Vec3,
    specular: Vec3,

    // directional / spot
    direction: Vec3 = .{ .x = 0, .y = -1, .z = 0 },

    // point / spot attenuation
    constant: f32 = 1.0,
    linear: f32 = 0.09,
    quadratic: f32 = 0.032,

    // spot cone (cosine of angles)
    cut_off: f32 = 0.9763, // cos(12.5 deg)
    outer_cut_off: f32 = 0.9659, // cos(15 deg)
};
