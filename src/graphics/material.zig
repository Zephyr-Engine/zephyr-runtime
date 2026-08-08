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
alpha_cutoff_location: ?GraphicsPipeline.UniformLocation,
allocator: std.mem.Allocator,

pub const TextureBinding = struct {
    unit: u16,
    view: TextureView,
    sampler: Sampler,
    resource_name: []const u8,
    /// Resolved once in `init`; `bindResources` runs per draw batch and should
    /// not pay for a uniform name lookup there.
    location: ?GraphicsPipeline.UniformLocation = null,
};

pub const ParamBinding = struct {
    param_index: usize,
    location: GraphicsPipeline.UniformLocation,
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

    for (source.param_entries, 0..) |param, i| {
        const location = device.graphicsPipelineUniformLocation(pipeline, param.name) orelse continue;
        try param_bindings.append(allocator, .{
            .param_index = i,
            .location = location,
        });
    }

    for (texture_bindings) |*binding| {
        binding.location = device.graphicsPipelineUniformLocation(pipeline, binding.resource_name);
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
