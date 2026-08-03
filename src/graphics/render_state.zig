const zimp = @import("zimp");

pub const FixedState = struct {
    depth_test: bool,
    depth_write: bool,

    cull_mode: zimp.CullMode,
    blend_mode: zimp.BlendMode,

    pub fn generate(state: zimp.RenderState) FixedState {
        return .{
            .depth_test = state.depth_test,
            .depth_write = state.depth_write,
            .cull_mode = if (state.double_sided) .none else state.cull_mode,
            .blend_mode = state.blend_mode,
        };
    }
};

pub const ColorLoadOp = union(enum) {
    load,
    clear: [4]f32,
};

pub const DepthLoadOp = union(enum) {
    load,
    clear: f32,
};

pub const BeginInfo = struct {
    color: ?ColorLoadOp = null,
    depth: ?DepthLoadOp = null,
};

test "FixedState preserves render state and disables culling for double-sided materials" {
    const single_sided: zimp.RenderState = .{
        .depth_test = true,
        .depth_write = false,
        .double_sided = false,
        .cull_mode = .front,
        .blend_mode = .alpha,
    };
    const double_sided = zimp.RenderState{
        .depth_test = single_sided.depth_test,
        .depth_write = single_sided.depth_write,
        .double_sided = true,
        .cull_mode = single_sided.cull_mode,
        .blend_mode = single_sided.blend_mode,
    };

    const fixed = FixedState.generate(single_sided);
    try @import("std").testing.expectEqual(single_sided.depth_test, fixed.depth_test);
    try @import("std").testing.expectEqual(single_sided.depth_write, fixed.depth_write);
    try @import("std").testing.expectEqual(single_sided.cull_mode, fixed.cull_mode);
    try @import("std").testing.expectEqual(single_sided.blend_mode, fixed.blend_mode);
    try @import("std").testing.expectEqual(zimp.CullMode.none, FixedState.generate(double_sided).cull_mode);
}
