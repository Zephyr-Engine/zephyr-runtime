const std = @import("std");
const Map = std.StringHashMap(i32);

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
    uniforms: Map,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, shader: *Shader) !Material {
        return .{
            .shader = shader,
            .uniforms = try shader.getUniformLocations(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Material) void {
        var it = self.uniforms.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.uniforms.deinit();
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
        const location = self.material.uniforms.get(name);
        if (location) |loc| {
            self.material.shader.bind();
            self.material.shader.setUniform(loc, value);
        } else {
            std.log.err("Could not find uniform with name: {s}", .{name});
        }
    }
};
