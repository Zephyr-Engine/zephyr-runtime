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
