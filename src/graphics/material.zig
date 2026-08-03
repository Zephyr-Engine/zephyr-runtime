const zimp = @import("zimp");
const std = @import("std");

const math = @import("../core/math.zig");

const Shader = @import("opengl/shader.zig").Shader;
const Texture2D = @import("opengl/texture.zig");

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

    pub fn bindResources(self: *const Material) void {
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
                .float => self.shader.setUniformFromLocation(binding.location, readF32(bytes[0..4])),
                .vec2 => self.shader.setUniformFromLocation(
                    binding.location,
                    math.Vec2.new(
                        readF32(bytes[0..4]),
                        readF32(bytes[4..8]),
                    ),
                ),
                .vec3 => self.shader.setUniformFromLocation(
                    binding.location,
                    math.Vec3.new(
                        readF32(bytes[0..4]),
                        readF32(bytes[4..8]),
                        readF32(bytes[8..12]),
                    ),
                ),
                .vec4 => self.shader.setUniformFromLocation(
                    binding.location,
                    math.Vec4.new(
                        readF32(bytes[0..4]),
                        readF32(bytes[4..8]),
                        readF32(bytes[8..12]),
                        readF32(bytes[12..16]),
                    ),
                ),
                .int => self.shader.setUniformFromLocation(
                    binding.location,
                    std.mem.readInt(i32, bytes[0..4], .little),
                ),
                .bool => {
                    const val: i32 = if (std.mem.readInt(u32, bytes[0..4], .little) != 0) 1 else 0;
                    self.shader.setUniformFromLocation(binding.location, val);
                },
            }
        }

        if (self.source.render_state.alpha_mode == .alpha_test) {
            self.shader.setUniform("u_alpha_cutoff", self.source.render_state.alpha_cutoff);
        }
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
