const zimp = @import("zimp");
const std = @import("std");

const math = @import("../core/math.zig");

const Material = @import("material.zig").Material;
const Mesh = @import("mesh.zig");

pub const DrawItem = struct {
    part: *const Mesh.Part,
    submesh: *const Mesh.Submesh,

    material_id: zimp.AssetId,
    material: *const Material,

    model: math.Mat4,
    depth_key: f32,

    phase: zimp.AlphaMode,
    pipeline_key: PipelineKey,

    pub fn lessThan(_: void, a: DrawItem, b: DrawItem) bool {
        if (a.phase != b.phase) {
            return @intFromEnum(a.phase) < @intFromEnum(b.phase);
        }

        return switch (a.phase) {
            .solid, .alpha_test => lessOpaqueLike(a, b),
            .alpha_blend => lessTransparentLike(a, b),
        };
    }
};

pub const PipelineKey = struct {
    shader_program_id: u32,

    depth_test: bool,
    depth_write: bool,

    cull_mode: zimp.CullMode,
    blend_mode: zimp.BlendMode,

    pub fn eql(a: PipelineKey, b: PipelineKey) bool {
        return std.meta.eql(a, b);
    }

    pub fn generate(material: *const Material) PipelineKey {
        const state = material.source.render_state;

        return .{
            .shader_program_id = material.shader.id,
            .depth_test = state.depth_test,
            .depth_write = state.depth_write,
            .cull_mode = if (state.double_sided) .none else state.cull_mode,
            .blend_mode = state.blend_mode,
        };
    }
};

fn lessOpaqueLike(a: DrawItem, b: DrawItem) bool {
    if (!a.pipeline_key.eql(b.pipeline_key)) {
        return pipelineLessThan(
            a.pipeline_key,
            b.pipeline_key,
        );
    }

    if (!zimp.AssetId.eql(
        a.material_id,
        b.material_id,
    )) {
        return assetIdLessThan(
            a.material_id,
            b.material_id,
        );
    }

    return a.depth_key < b.depth_key;
}

fn lessTransparentLike(a: DrawItem, b: DrawItem) bool {
    if (a.depth_key != b.depth_key) {
        return a.depth_key > b.depth_key;
    }

    if (!a.pipeline_key.eql(b.pipeline_key)) {
        return pipelineLessThan(
            a.pipeline_key,
            b.pipeline_key,
        );
    }

    return assetIdLessThan(
        a.material_id,
        b.material_id,
    );
}

fn assetIdLessThan(
    a: zimp.AssetId,
    b: zimp.AssetId,
) bool {
    return std.mem.order(
        u8,
        &a.uuid.bytes,
        &b.uuid.bytes,
    ) == .lt;
}

fn pipelineLessThan(
    a: PipelineKey,
    b: PipelineKey,
) bool {
    if (a.shader_program_id != b.shader_program_id) {
        return a.shader_program_id <
            b.shader_program_id;
    }

    if (a.depth_test != b.depth_test) {
        return !a.depth_test and b.depth_test;
    }

    if (a.depth_write != b.depth_write) {
        return !a.depth_write and b.depth_write;
    }

    if (a.cull_mode != b.cull_mode) {
        return @intFromEnum(a.cull_mode) <
            @intFromEnum(b.cull_mode);
    }

    if (a.blend_mode != b.blend_mode) {
        return @intFromEnum(a.blend_mode) <
            @intFromEnum(b.blend_mode);
    }

    return false;
}
