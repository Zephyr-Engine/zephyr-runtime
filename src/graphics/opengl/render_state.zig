const std = @import("std");

const render_state = @import("../render_state.zig");
const c = @import("../../c.zig");
const gl = c.glad;

var applied: ?render_state.FixedState = null;

pub fn apply(state: render_state.FixedState) void {
    if (applied) |current| {
        if (std.meta.eql(current, state)) {
            return;
        }
    }
    applied = state;

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

pub fn begin(info: render_state.BeginInfo) void {
    applied = null;

    var clear_mask: c_uint = 0;

    if (info.color) |col| {
        switch (col) {
            .load => {},
            .clear => |color| {
                gl.glColorMask(
                    gl.GL_TRUE,
                    gl.GL_TRUE,
                    gl.GL_TRUE,
                    gl.GL_TRUE,
                );

                gl.glClearColor(
                    color[0],
                    color[1],
                    color[2],
                    color[3],
                );

                clear_mask |= gl.GL_COLOR_BUFFER_BIT;
            },
        }
    }

    if (info.depth) |d| {
        switch (d) {
            .load => {},
            .clear => |depth| {
                gl.glDepthMask(gl.GL_TRUE);
                gl.glClearDepth(depth);

                clear_mask |= gl.GL_DEPTH_BUFFER_BIT;
            },
        }
    }

    if (clear_mask != 0) {
        gl.glClear(clear_mask);
    }
}
