const std = @import("std");
const Map = std.StringHashMap(i32);
const Shader = @import("../graphics/opengl_shader.zig").Shader;

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

    pub fn setUniform(self: *const Material, name: []const u8, value: anytype) void {
        const location = self.uniforms.get(name);
        if (location) |loc| {
            self.shader.bind();
            self.shader.setUniform(loc, value);
        } else {
            std.log.err("Could not find uniform with name: {s}", .{name});
        }
    }

    pub fn deinit(self: *Material) void {
        // Free all the allocated uniform name strings
        var it = self.uniforms.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.uniforms.deinit();
    }
};
