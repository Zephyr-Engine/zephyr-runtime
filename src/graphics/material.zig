const std = @import("std");

const c = @import("../c.zig");
const zimp = @import("zimp");
const gl = c.glad;

const Shader = @import("opengl/shader.zig").Shader;
const Texture2D = @import("opengl/texture.zig").Texture2D;

pub const Material = struct {
    shader: *Shader,
    source: zimp.Zamat,
    texture_bindings: []TextureBinding,
    param_bindings: []ParamBinding,
    allocator: std.mem.Allocator,

    pub const TextureBinding = struct {
        unit: u16,
        texture: *Texture2D,
        resource_name: []const u8,
    };

    pub const ParamBinding = struct {
        param_index: usize,
        location: i32,
    };

    pub fn initFromSource(
        allocator: std.mem.Allocator,
        source: zimp.Zamat,
        shader: *Shader,
        texture_bindings: []TextureBinding,
    ) !Material {
        var param_bindings = std.ArrayList(ParamBinding).empty;
        errdefer param_bindings.deinit(allocator);

        for (source.param_entries, 0..) |param, i| {
            const location = shader.uniformLocation(param.name) orelse continue;
            try param_bindings.append(allocator, .{
                .param_index = i,
                .location = location,
            });
        }

        return .{
            .shader = shader,
            .source = source,
            .texture_bindings = texture_bindings,
            .param_bindings = try param_bindings.toOwnedSlice(allocator),
            .allocator = allocator,
        };
    }

    pub fn bind(self: *const Material) void {
        self.shader.bind();

        for (self.texture_bindings) |*binding| {
            binding.texture.bind(binding.unit);
            self.shader.setUniform(binding.resource_name, @as(i32, @intCast(binding.unit)));
        }

        for (self.param_bindings) |binding| {
            const param = self.source.param_entries[binding.param_index];
            const start: usize = param.data_offset;
            const end = start + param.data_size;
            if (end > self.source.param_data.len) {
                continue;
            }
            const bytes = self.source.param_data[start..end];

            switch (param.param_type) {
                .float => gl.glUniform1f(binding.location, readF32(bytes[0..4])),
                .vec2 => gl.glUniform2f(
                    binding.location,
                    readF32(bytes[0..4]),
                    readF32(bytes[4..8]),
                ),
                .vec3 => gl.glUniform3f(
                    binding.location,
                    readF32(bytes[0..4]),
                    readF32(bytes[4..8]),
                    readF32(bytes[8..12]),
                ),
                .vec4 => gl.glUniform4f(
                    binding.location,
                    readF32(bytes[0..4]),
                    readF32(bytes[4..8]),
                    readF32(bytes[8..12]),
                    readF32(bytes[12..16]),
                ),
                .int => gl.glUniform1i(
                    binding.location,
                    std.mem.readInt(i32, bytes[0..4], .little),
                ),
                .bool => gl.glUniform1i(binding.location, if (std.mem.readInt(u32, bytes[0..4], .little) != 0) 1 else 0),
            }
        }
    }

    pub fn setUniform(self: *const Material, name: []const u8, value: anytype) void {
        self.shader.setUniform(name, value);
    }

    pub fn deinit(self: *Material) void {
        self.allocator.free(self.texture_bindings);
        self.allocator.free(self.param_bindings);
        self.source.deinit(self.allocator);
    }
};

fn readF32(bytes: *const [4]u8) f32 {
    return @bitCast(std.mem.readInt(u32, bytes, .little));
}

test "readF32 decodes little-endian parameter data" {
    const bytes = [_]u8{ 0x00, 0x00, 0xc0, 0x3f };
    try std.testing.expectEqual(@as(f32, 1.5), readF32(&bytes));
}
