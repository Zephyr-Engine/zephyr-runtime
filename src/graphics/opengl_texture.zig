const c = @import("../c.zig");
const gl = c.glad;

pub const TextureFormat = enum {
    r8,
    rgba8,

    fn toGLFormat(self: TextureFormat) c_uint {
        return switch (self) {
            .r8 => gl.GL_RED,
            .rgba8 => gl.GL_RGBA,
        };
    }

    fn toGLInternalFormat(self: TextureFormat) c_int {
        return switch (self) {
            .r8 => gl.GL_R8,
            .rgba8 => gl.GL_RGBA8,
        };
    }
};

pub const TextureError = error{
    TextureCreationFailed,
    OpenGLError,
};

pub const Texture = struct {
    id: u32,
    width: i32,
    height: i32,
    format: TextureFormat,

    pub fn init(width: i32, height: i32, format: TextureFormat, data: ?[*]const u8) TextureError!Texture {
        var texture = Texture{
            .id = 0,
            .width = width,
            .height = height,
            .format = format,
        };

        gl.glGenTextures(1, &texture.id);
        if (texture.id == 0) {
            return TextureError.TextureCreationFailed;
        }

        gl.glBindTexture(gl.GL_TEXTURE_2D, texture.id);

        // Set texture parameters
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);

        // For single-channel textures, set swizzle mask
        if (format == .r8) {
            gl.glPixelStorei(gl.GL_UNPACK_ALIGNMENT, 1);
        }

        gl.glTexImage2D(
            gl.GL_TEXTURE_2D,
            0,
            format.toGLInternalFormat(),
            width,
            height,
            0,
            format.toGLFormat(),
            gl.GL_UNSIGNED_BYTE,
            data,
        );

        const err = gl.glGetError();
        if (err != gl.GL_NO_ERROR) {
            gl.glDeleteTextures(1, &texture.id);
            return TextureError.OpenGLError;
        }

        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
        return texture;
    }

    pub fn deinit(self: *Texture) void {
        if (self.id != 0) {
            gl.glDeleteTextures(1, &self.id);
            self.id = 0;
        }
    }

    pub fn bind(self: Texture, unit: u32) void {
        gl.glActiveTexture(gl.GL_TEXTURE0 + unit);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.id);
    }

    pub fn unbind() void {
        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
    }

    pub fn update(self: Texture, x: i32, y: i32, width: i32, height: i32, data: [*]const u8) void {
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.id);
        if (self.format == .r8) {
            gl.glPixelStorei(gl.GL_UNPACK_ALIGNMENT, 1);
        }
        gl.glTexSubImage2D(
            gl.GL_TEXTURE_2D,
            0,
            x,
            y,
            width,
            height,
            self.format.toGLFormat(),
            gl.GL_UNSIGNED_BYTE,
            data,
        );
        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
    }
};
