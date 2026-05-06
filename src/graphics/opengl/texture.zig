const std = @import("std");
const zimp = @import("zimp");
const c = @import("../../c.zig");
const gl = c.glad;

pub const TextureError = error{
    TextureCreationFailed,
    UnsupportedTextureType,
    UnsupportedTextureFormat,
    OpenGLError,
};

pub const Texture2D = struct {
    id: u32,
    width: u32,
    height: u32,

    pub fn init(tex: zimp.Zatex) TextureError!Texture2D {
        if (tex.texture_type != .texture_2d) {
            return TextureError.UnsupportedTextureType;
        }

        var id: u32 = 0;
        gl.glGenTextures(1, &id);
        if (id == 0) {
            return TextureError.TextureCreationFailed;
        }
        errdefer gl.glDeleteTextures(1, &id);

        gl.glBindTexture(gl.GL_TEXTURE_2D, id);
        gl.glTexParameteri(
            gl.GL_TEXTURE_2D,
            gl.GL_TEXTURE_MIN_FILTER,
            if (tex.mips.len > 1) gl.GL_LINEAR_MIPMAP_LINEAR else gl.GL_LINEAR,
        );
        gl.glTexParameteri(
            gl.GL_TEXTURE_2D,
            gl.GL_TEXTURE_MAG_FILTER,
            gl.GL_LINEAR,
        );
        gl.glTexParameteri(
            gl.GL_TEXTURE_2D,
            gl.GL_TEXTURE_WRAP_S,
            gl.GL_REPEAT,
        );
        gl.glTexParameteri(
            gl.GL_TEXTURE_2D,
            gl.GL_TEXTURE_WRAP_T,
            gl.GL_REPEAT,
        );
        var max_anisotrophy: f32 = 1.0;
        gl.glGetFloatv(gl.GL_MAX_TEXTURE_MAX_ANISOTROPY, &max_anisotrophy);
        if (max_anisotrophy > 1.0) {
            gl.glTexParameterf(
                gl.GL_TEXTURE_2D,
                gl.GL_TEXTURE_MAX_ANISOTROPY,
                @min(max_anisotrophy, 8.0),
            );
        }
        gl.glTexParameteri(
            gl.GL_TEXTURE_2D,
            gl.GL_TEXTURE_BASE_LEVEL,
            0,
        );
        gl.glTexParameteri(
            gl.GL_TEXTURE_2D,
            gl.GL_TEXTURE_MAX_LEVEL,
            @intCast(tex.mips.len - 1),
        );

        const is_block_compressed = tex.format.isBlockCompressed();
        for (tex.mips, 0..) |mip, level| {
            if (is_block_compressed) {
                gl.glCompressedTexImage2D(
                    gl.GL_TEXTURE_2D,
                    @intCast(level),
                    compressedInternalFormat(tex.format, tex.color_space),
                    @intCast(mip.width),
                    @intCast(mip.height),
                    0,
                    @intCast(mip.data.len),
                    mip.data.ptr,
                );
            } else {
                const fmt = uncompressedFormat(tex.format, tex.color_space);
                gl.glTexImage2D(
                    gl.GL_TEXTURE_2D,
                    @intCast(level),
                    @intCast(fmt.internal),
                    @intCast(mip.width),
                    @intCast(mip.height),
                    0,
                    fmt.format,
                    fmt.ty,
                    mip.data.ptr,
                );
            }
        }

        const err = gl.glGetError();
        if (err != gl.GL_NO_ERROR) {
            return TextureError.OpenGLError;
        }

        return .{ .id = id, .width = tex.width, .height = tex.height };
    }

    pub fn bind(self: *const Texture2D, unit: u16) void {
        gl.glActiveTexture(@intCast(gl.GL_TEXTURE0 + @as(c_int, @intCast(unit))));
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.id);
    }

    pub fn deinit(self: *Texture2D) void {
        gl.glDeleteTextures(1, &self.id);
        self.id = 0;
    }
};

const UploadFormat = struct {
    internal: u32,
    format: u32,
    ty: u32,
};

fn uncompressedFormat(format: anytype, color_space: anytype) UploadFormat {
    return switch (format) {
        .rgba8 => .{ .internal = if (color_space == .srgb) gl.GL_SRGB8_ALPHA8 else gl.GL_RGBA8, .format = gl.GL_RGBA, .ty = gl.GL_UNSIGNED_BYTE },
        .rg8 => .{ .internal = gl.GL_RG8, .format = gl.GL_RG, .ty = gl.GL_UNSIGNED_BYTE },
        .r8 => .{ .internal = gl.GL_R8, .format = gl.GL_RED, .ty = gl.GL_UNSIGNED_BYTE },
        .rgb16f => .{ .internal = gl.GL_RGB16F, .format = gl.GL_RGB, .ty = gl.GL_HALF_FLOAT },
        else => unreachable,
    };
}

fn compressedInternalFormat(format: anytype, color_space: anytype) u32 {
    return switch (format) {
        .bc4 => gl.GL_COMPRESSED_RED_RGTC1,
        .bc5 => gl.GL_COMPRESSED_RG_RGTC2,
        .bc7 => if (color_space == .srgb) gl.GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM else gl.GL_COMPRESSED_RGBA_BPTC_UNORM,
        .bc6h => gl.GL_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT,
        else => unreachable,
    };
}
