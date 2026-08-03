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

fn drawItem(phase: zimp.AlphaMode, depth_key: f32, material_id: zimp.AssetId, pipeline_key: PipelineKey) DrawItem {
    return .{
        .part = undefined,
        .submesh = undefined,
        .material_id = material_id,
        .material = undefined,
        .model = undefined,
        .depth_key = depth_key,
        .phase = phase,
        .pipeline_key = pipeline_key,
    };
}

const pipeline_a = PipelineKey{
    .shader_program_id = 1,
    .depth_test = true,
    .depth_write = true,
    .cull_mode = .back,
    .blend_mode = .disabled,
};

const pipeline_b = PipelineKey{
    .shader_program_id = 2,
    .depth_test = true,
    .depth_write = true,
    .cull_mode = .back,
    .blend_mode = .disabled,
};

const material_a = zimp.AssetId.parseComptime("11111111-1111-4111-8111-111111111111");
const material_b = zimp.AssetId.parseComptime("22222222-2222-4222-8222-222222222222");

test "draw items sort render phases before their per-phase keys" {
    var items = [_]DrawItem{
        drawItem(.alpha_blend, 10, material_b, pipeline_b),
        drawItem(.solid, 3, material_b, pipeline_b),
        drawItem(.alpha_test, 2, material_a, pipeline_a),
    };

    std.mem.sort(DrawItem, &items, {}, DrawItem.lessThan);

    try std.testing.expectEqual(zimp.AlphaMode.solid, items[0].phase);
    try std.testing.expectEqual(zimp.AlphaMode.alpha_test, items[1].phase);
    try std.testing.expectEqual(zimp.AlphaMode.alpha_blend, items[2].phase);
}

test "opaque draw items batch by pipeline then material then front-to-back depth" {
    var items = [_]DrawItem{
        drawItem(.solid, 5, material_a, pipeline_a),
        drawItem(.solid, 3, material_b, pipeline_a),
        drawItem(.solid, 1, material_a, pipeline_a),
        drawItem(.solid, 2, material_a, pipeline_b),
    };

    std.mem.sort(DrawItem, &items, {}, DrawItem.lessThan);

    try std.testing.expect(items[0].pipeline_key.eql(pipeline_a));
    try std.testing.expect(items[0].material_id.eql(material_a));
    try std.testing.expectEqual(@as(f32, 1), items[0].depth_key);
    try std.testing.expectEqual(@as(f32, 5), items[1].depth_key);
    try std.testing.expect(items[2].material_id.eql(material_b));
    try std.testing.expect(items[3].pipeline_key.eql(pipeline_b));
}

test "transparent draw items sort back-to-front before batching ties" {
    var items = [_]DrawItem{
        drawItem(.alpha_blend, 2, material_b, pipeline_b),
        drawItem(.alpha_blend, 8, material_b, pipeline_b),
        drawItem(.alpha_blend, 8, material_a, pipeline_b),
        drawItem(.alpha_blend, 8, material_a, pipeline_a),
    };

    std.mem.sort(DrawItem, &items, {}, DrawItem.lessThan);

    try std.testing.expectEqual(@as(f32, 8), items[0].depth_key);
    try std.testing.expect(items[0].pipeline_key.eql(pipeline_a));
    try std.testing.expect(items[1].pipeline_key.eql(pipeline_b));
    try std.testing.expect(items[1].material_id.eql(material_a));
    try std.testing.expectEqual(@as(f32, 2), items[3].depth_key);
}

test "pipeline ordering includes every fixed-state field" {
    const base = pipeline_a;
    const Case = struct { value: PipelineKey, base_first: bool };
    const cases = [_]Case{
        .{ .value = .{ .shader_program_id = 2, .depth_test = true, .depth_write = true, .cull_mode = .back, .blend_mode = .disabled }, .base_first = true },
        .{ .value = .{ .shader_program_id = 1, .depth_test = false, .depth_write = true, .cull_mode = .back, .blend_mode = .disabled }, .base_first = false },
        .{ .value = .{ .shader_program_id = 1, .depth_test = true, .depth_write = false, .cull_mode = .back, .blend_mode = .disabled }, .base_first = false },
        .{ .value = .{ .shader_program_id = 1, .depth_test = true, .depth_write = true, .cull_mode = .front, .blend_mode = .disabled }, .base_first = false },
        .{ .value = .{ .shader_program_id = 1, .depth_test = true, .depth_write = true, .cull_mode = .back, .blend_mode = .alpha }, .base_first = true },
    };

    try std.testing.expect(base.eql(base));
    for (cases) |case| {
        try std.testing.expect(!base.eql(case.value));
        try std.testing.expectEqual(case.base_first, pipelineLessThan(base, case.value));
        try std.testing.expectEqual(!case.base_first, pipelineLessThan(case.value, base));
    }
}
