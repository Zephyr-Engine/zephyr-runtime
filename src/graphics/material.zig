const zimp = @import("zimp");
const std = @import("std");

const GraphicsPipeline = @import("rhi/graphics_pipeline.zig");
const TextureView = @import("rhi/texture_view.zig");
const Sampler = @import("rhi/sampler.zig");
const Device = @import("rhi/device.zig");

const Material = @This();

pipeline: GraphicsPipeline,
device: *Device,
source: zimp.Zamat,
texture_bindings: []TextureBinding,
param_bindings: []ParamBinding,
slot_uniform_bindings: []UniformBinding,
alpha_cutoff_location: ?GraphicsPipeline.UniformLocation,
allocator: std.mem.Allocator,

pub const TextureBinding = struct {
    unit: u16,
    view: TextureView,
    sampler: Sampler,
    sampler_name: []const u8,
    uv_set: u32,
    uv_offset: [2]f32,
    uv_scale: [2]f32,
    uv_rotation: f32,
    normal_scale: f32,
    occlusion_strength: f32,
    /// Resolved once in `init`; `bindResources` runs per draw batch and should
    /// not pay for a uniform name lookup there.
    location: ?GraphicsPipeline.UniformLocation = null,

    fn uvTransform(self: TextureBinding) [3][3]f32 {
        const c = @cos(self.uv_rotation);
        const s = @sin(self.uv_rotation);
        const sx = self.uv_scale[0];
        const sy = self.uv_scale[1];

        // offset + rotation * (scale * uv)
        return .{
            .{ c * sx, s * sx, 0 },
            .{ -s * sy, c * sy, 0 },
            .{ self.uv_offset[0], self.uv_offset[1], 1 },
        };
    }
};

pub const ParamBinding = struct {
    param_index: usize,
    location: GraphicsPipeline.UniformLocation,
};

pub const UniformBinding = struct {
    location: GraphicsPipeline.UniformLocation,
    value: GraphicsPipeline.UniformValue,
};

pub fn init(
    allocator: std.mem.Allocator,
    source: zimp.Zamat,
    pipeline: GraphicsPipeline,
    texture_bindings: []TextureBinding,
    device: *Device,
) !Material {
    var param_bindings = std.ArrayList(ParamBinding).empty;
    errdefer param_bindings.deinit(allocator);

    var slot_uniforms: std.ArrayList(UniformBinding) = .empty;
    errdefer slot_uniforms.deinit(allocator);

    for (source.param_entries, 0..) |param, i| {
        const location = device.graphicsPipelineUniformLocation(pipeline, param.name) orelse continue;
        try param_bindings.append(allocator, .{
            .param_index = i,
            .location = location,
        });
    }

    for (texture_bindings) |*binding| {
        binding.location = device.graphicsPipelineUniformLocation(pipeline, binding.sampler_name);

        const set_name = try std.fmt.allocPrint(allocator, "{s}_uv_set", .{binding.sampler_name});
        defer allocator.free(set_name);

        if (device.graphicsPipelineUniformLocation(pipeline, set_name)) |location| {
            try slot_uniforms.append(allocator, .{
                .location = location,
                .value = .{ .int = @intCast(binding.uv_set) },
            });
        }

        const transform_name = try std.fmt.allocPrint(
            allocator,
            "{s}_uv_transform",
            .{binding.sampler_name},
        );
        defer allocator.free(transform_name);

        if (device.graphicsPipelineUniformLocation(
            pipeline,
            transform_name,
        )) |location| {
            try slot_uniforms.append(allocator, .{
                .location = location,
                .value = .{ .mat3 = binding.uvTransform() },
            });
        }

        if (std.mem.eql(u8, binding.sampler_name, "u_normal_map")) {
            if (device.graphicsPipelineUniformLocation(
                pipeline,
                "u_normal_scale",
            )) |location| {
                try slot_uniforms.append(allocator, .{
                    .location = location,
                    .value = .{ .float = binding.normal_scale },
                });
            }
        }

        if (std.mem.eql(u8, binding.sampler_name, "u_ao_map")) {
            if (device.graphicsPipelineUniformLocation(
                pipeline,
                "u_occlusion_strength",
            )) |location| {
                try slot_uniforms.append(allocator, .{
                    .location = location,
                    .value = .{ .float = binding.occlusion_strength },
                });
            }
        }
    }

    const alpha_cutoff_location = if (source.render_state.alpha_mode == .alpha_test)
        device.graphicsPipelineUniformLocation(pipeline, "u_alpha_cutoff")
    else
        null;

    return .{
        .pipeline = pipeline,
        .device = device,
        .source = source,
        .texture_bindings = texture_bindings,
        .alpha_cutoff_location = alpha_cutoff_location,
        .slot_uniform_bindings = try slot_uniforms.toOwnedSlice(allocator),
        .param_bindings = try param_bindings.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

pub fn bindResources(self: *const Material) void {
    for (self.texture_bindings) |*binding| {
        self.device.bindTexture(binding.view, binding.sampler, binding.unit);
        if (binding.location) |location| {
            self.device.setGraphicsPipelineUniform(self.pipeline, location, .{ .int = @intCast(binding.unit) });
        }
    }

    for (self.slot_uniform_bindings) |binding| {
        self.device.setGraphicsPipelineUniform(
            self.pipeline,
            binding.location,
            binding.value,
        );
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
            .float => self.device.setGraphicsPipelineUniform(self.pipeline, binding.location, .{ .float = readF32(bytes[0..4]) }),
            .vec2 => self.device.setGraphicsPipelineUniform(
                self.pipeline,
                binding.location,
                .{ .vec2 = .{
                    readF32(bytes[0..4]),
                    readF32(bytes[4..8]),
                } },
            ),
            .vec3 => self.device.setGraphicsPipelineUniform(
                self.pipeline,
                binding.location,
                .{ .vec3 = .{
                    readF32(bytes[0..4]),
                    readF32(bytes[4..8]),
                    readF32(bytes[8..12]),
                } },
            ),
            .vec4 => self.device.setGraphicsPipelineUniform(
                self.pipeline,
                binding.location,
                .{ .vec4 = .{
                    readF32(bytes[0..4]),
                    readF32(bytes[4..8]),
                    readF32(bytes[8..12]),
                    readF32(bytes[12..16]),
                } },
            ),
            .int => self.device.setGraphicsPipelineUniform(
                self.pipeline,
                binding.location,
                .{ .int = std.mem.readInt(i32, bytes[0..4], .little) },
            ),
            .bool => {
                const val: i32 = if (std.mem.readInt(u32, bytes[0..4], .little) != 0) 1 else 0;
                self.device.setGraphicsPipelineUniform(self.pipeline, binding.location, .{ .int = val });
            },
        }
    }

    if (self.alpha_cutoff_location) |location| {
        self.device.setGraphicsPipelineUniform(
            self.pipeline,
            location,
            .{ .float = self.source.render_state.alpha_cutoff },
        );
    }
}

pub fn deinit(self: *Material) void {
    self.allocator.free(self.slot_uniform_bindings);
    self.allocator.free(self.texture_bindings);
    self.allocator.free(self.param_bindings);
    self.source.deinit(self.allocator);
}

fn readF32(bytes: *const [4]u8) f32 {
    return @bitCast(std.mem.readInt(u32, bytes, .little));
}

test "readF32 decodes little-endian parameter data" {
    const bytes = [_]u8{ 0x00, 0x00, 0xc0, 0x3f };
    try std.testing.expectEqual(@as(f32, 1.5), readF32(&bytes));
}
