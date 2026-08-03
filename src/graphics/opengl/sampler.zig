const diagnostics = @import("diagnostics.zig");
const Sampler = @import("../rhi/sampler.zig");
const gl = @import("../../c.zig").glad;

const OpenGLSampler = @This();
id: u32,

pub fn init(desc: Sampler.Desc) !OpenGLSampler {
    var id: u32 = 0;
    gl.glGenSamplers(1, &id);
    if (id == 0) {
        return error.SamplerCreationFailed;
    }
    errdefer gl.glDeleteSamplers(1, &id);

    gl.glSamplerParameteri(id, gl.GL_TEXTURE_MIN_FILTER, minFilter(desc));
    gl.glSamplerParameteri(id, gl.GL_TEXTURE_MAG_FILTER, if (desc.mag_filter == .linear) gl.GL_LINEAR else gl.GL_NEAREST);
    gl.glSamplerParameteri(id, gl.GL_TEXTURE_WRAP_S, address(desc.address_u));
    gl.glSamplerParameteri(id, gl.GL_TEXTURE_WRAP_T, address(desc.address_v));

    if (desc.max_anisotropy > 1 and diagnostics.hasExtension("GL_EXT_texture_filter_anisotropic")) {
        var supported: f32 = 1;
        gl.glGetFloatv(gl.GL_MAX_TEXTURE_MAX_ANISOTROPY, &supported);
        gl.glSamplerParameterf(id, gl.GL_TEXTURE_MAX_ANISOTROPY, @min(desc.max_anisotropy, supported));
    }

    if (!diagnostics.checkError("creating sampler")) {
        return error.OpenGLError;
    }
    return .{ .id = id };
}

pub fn deinit(self: *OpenGLSampler) void {
    gl.glDeleteSamplers(1, &self.id);
    self.id = 0;
}

fn minFilter(desc: Sampler.Desc) c_int {
    return switch (desc.mip_filter) {
        .none => if (desc.min_filter == .linear) gl.GL_LINEAR else gl.GL_NEAREST,
        .nearest => if (desc.min_filter == .linear) gl.GL_LINEAR_MIPMAP_NEAREST else gl.GL_NEAREST_MIPMAP_NEAREST,
        .linear => if (desc.min_filter == .linear) gl.GL_LINEAR_MIPMAP_LINEAR else gl.GL_NEAREST_MIPMAP_LINEAR,
    };
}

fn address(mode: Sampler.AddressMode) c_int {
    return switch (mode) {
        .repeat => gl.GL_REPEAT,
        .clamp_to_edge => gl.GL_CLAMP_TO_EDGE,
    };
}
