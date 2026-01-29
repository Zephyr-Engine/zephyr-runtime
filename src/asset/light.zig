const Vec3 = @import("../core/math.zig").Vec3;

pub const Light = struct {
    position: Vec3,
    ambient: Vec3,
    diffuse: Vec3,
    specular: Vec3,
};
