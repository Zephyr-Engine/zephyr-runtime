const std = @import("std");

const math = @import("../core/math.zig");
const Shader = @import("../graphics/opengl_shader.zig").Shader;

pub const Lighting = struct {
    ambient: math.Vec3,
    diffuse: math.Vec3,
    specular: math.Vec3,
    shininess: f32,
};

pub const Material = struct {
    shader: *Shader,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, shader: *Shader) Material {
        return .{
            .shader = shader,
            .allocator = allocator,
        };
    }

    pub fn instaniate(self: *const Material, lighting: Lighting) MaterialInstance {
        const instance = MaterialInstance{
            .material = self,
            .lighting = lighting,
        };

        return instance;
    }
};

pub const MaterialInstance = struct {
    material: *const Material,
    lighting: Lighting,

    pub fn setUniform(self: *const MaterialInstance, name: []const u8, value: anytype) void {
        self.material.shader.bind();
        self.material.shader.setUniform(name, value);
    }
};
