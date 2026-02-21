const std = @import("std");

const math = @import("../core/math.zig");
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const Texture = @import("../graphics/opengl_texture.zig").Texture;

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
    base_color_texture: ?*const Texture = null,
    metallic_roughness_texture: ?*const Texture = null,
    normal_texture: ?*const Texture = null,

    pub fn setUniform(self: *const MaterialInstance, name: []const u8, value: anytype) void {
        self.material.shader.bind();
        self.material.shader.setUniform(name, value);
    }

    pub fn hasTextures(self: *const MaterialInstance) bool {
        return self.base_color_texture != null or
            self.metallic_roughness_texture != null or
            self.normal_texture != null;
    }

    pub fn bindTextures(self: *const MaterialInstance) void {
        if (self.base_color_texture) |tex| {
            tex.bind(0);
        }
        if (self.metallic_roughness_texture) |tex| {
            tex.bind(1);
        }
        if (self.normal_texture) |tex| {
            tex.bind(2);
        }
    }
};
