const FixedState = @import("../render_state.zig").FixedState;

const c = @import("../../c.zig");
const gl = c.glad;

pub fn apply(state: FixedState) void {
    if (state.depth_test) {
        gl.glEnable(gl.GL_DEPTH_TEST);
    } else {
        gl.glDisable(gl.GL_DEPTH_TEST);
    }

    gl.glDepthMask(
        if (state.depth_write)
            gl.GL_TRUE
        else
            gl.GL_FALSE,
    );

    switch (state.cull_mode) {
        .none => gl.glDisable(gl.GL_CULL_FACE),
        .front, .back => {
            gl.glEnable(gl.GL_CULL_FACE);
            gl.glCullFace(switch (state.cull_mode) {
                .none => unreachable,
                .front => gl.GL_FRONT,
                .back => gl.GL_BACK,
            });
        },
    }

    switch (state.blend_mode) {
        .disabled => {
            gl.glDisable(gl.GL_BLEND);
        },
        .alpha => {
            gl.glEnable(gl.GL_BLEND);
            gl.glBlendEquation(gl.GL_FUNC_ADD);
            gl.glBlendFunc(
                gl.GL_SRC_ALPHA,
                gl.GL_ONE_MINUS_SRC_ALPHA,
            );
        },
        .premultiplied_alpha => {
            gl.glEnable(gl.GL_BLEND);
            gl.glBlendEquation(gl.GL_FUNC_ADD);
            gl.glBlendFunc(
                gl.GL_ONE,
                gl.GL_ONE_MINUS_SRC_ALPHA,
            );
        },
    }
}
