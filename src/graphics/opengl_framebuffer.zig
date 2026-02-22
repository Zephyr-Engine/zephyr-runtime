const c = @import("../c.zig");
const gl = c.glad;

pub const FramebufferError = error{
    FramebufferCreationFailed,
    RenderbufferCreationFailed,
    FramebufferIncomplete,
    OpenGLError,
    TooManyAttachments,
};

pub const AttachmentFormat = enum {
    rgba8,
    rgba16f,
    rg16f,
    r32f,
    r8,
    rgb8,
    depth24_stencil8,

    fn glInternalFormat(self: AttachmentFormat) c_int {
        return switch (self) {
            .rgba8 => gl.GL_RGBA8,
            .rgba16f => gl.GL_RGBA16F,
            .rg16f => gl.GL_RG16F,
            .r32f => gl.GL_R32F,
            .r8 => gl.GL_R8,
            .rgb8 => gl.GL_RGB8,
            .depth24_stencil8 => gl.GL_DEPTH24_STENCIL8,
        };
    }

    fn glFormat(self: AttachmentFormat) c_uint {
        return switch (self) {
            .rgba8, .rgba16f => gl.GL_RGBA,
            .rg16f => gl.GL_RG,
            .r32f, .r8 => gl.GL_RED,
            .rgb8 => gl.GL_RGB,
            .depth24_stencil8 => gl.GL_DEPTH_STENCIL,
        };
    }

    fn glType(self: AttachmentFormat) c_uint {
        return switch (self) {
            .rgba8, .r8, .rgb8 => gl.GL_UNSIGNED_BYTE,
            .rgba16f, .rg16f, .r32f => gl.GL_FLOAT,
            .depth24_stencil8 => gl.GL_UNSIGNED_INT_24_8,
        };
    }


};

pub const FramebufferConfig = struct {
    width: i32,
    height: i32,
    color_formats: []const AttachmentFormat = &.{.rgba8},
    has_depth_stencil: bool = true,
    depth_as_texture: bool = false,
};

pub const MAX_COLOR_ATTACHMENTS = 8;

pub const Framebuffer = struct {
    id: u32,
    color_textures: [MAX_COLOR_ATTACHMENTS]u32,
    color_formats: [MAX_COLOR_ATTACHMENTS]AttachmentFormat,
    color_count: u32,
    depth_renderbuffer: u32,
    depth_texture: u32,
    has_depth_stencil: bool,
    depth_as_texture: bool,
    width: i32,
    height: i32,

    pub fn getColorTexture(self: Framebuffer) u32 {
        return self.color_textures[0];
    }

    pub fn init(width: i32, height: i32) FramebufferError!Framebuffer {
        return initWithConfig(.{
            .width = width,
            .height = height,
        });
    }

    pub fn initDepthOnly(width: i32, height: i32) FramebufferError!Framebuffer {
        return initWithConfig(.{
            .width = width,
            .height = height,
            .color_formats = &.{},
            .has_depth_stencil = true,
            .depth_as_texture = true,
        });
    }

    pub fn initWithConfig(config: FramebufferConfig) FramebufferError!Framebuffer {
        if (config.color_formats.len > MAX_COLOR_ATTACHMENTS) {
            return FramebufferError.TooManyAttachments;
        }

        var fb = Framebuffer{
            .id = 0,
            .color_textures = [_]u32{0} ** MAX_COLOR_ATTACHMENTS,
            .color_formats = [_]AttachmentFormat{.rgba8} ** MAX_COLOR_ATTACHMENTS,
            .color_count = @intCast(config.color_formats.len),
            .depth_renderbuffer = 0,
            .depth_texture = 0,
            .has_depth_stencil = config.has_depth_stencil,
            .depth_as_texture = config.depth_as_texture,
            .width = config.width,
            .height = config.height,
        };

        for (config.color_formats, 0..) |fmt, i| {
            fb.color_formats[i] = fmt;
        }

        // Create framebuffer
        gl.glGenFramebuffers(1, &fb.id);
        if (fb.id == 0) {
            return FramebufferError.FramebufferCreationFailed;
        }
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, fb.id);

        // Create color texture attachments
        for (0..fb.color_count) |i| {
            const fmt = fb.color_formats[i];
            gl.glGenTextures(1, &fb.color_textures[i]);
            if (fb.color_textures[i] == 0) {
                fb.cleanup();
                return FramebufferError.FramebufferCreationFailed;
            }

            gl.glBindTexture(gl.GL_TEXTURE_2D, fb.color_textures[i]);
            gl.glTexImage2D(
                gl.GL_TEXTURE_2D,
                0,
                fmt.glInternalFormat(),
                config.width,
                config.height,
                0,
                fmt.glFormat(),
                fmt.glType(),
                null,
            );
            gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
            gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
            gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
            gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
            gl.glFramebufferTexture2D(
                gl.GL_FRAMEBUFFER,
                @intCast(@as(c_uint, gl.GL_COLOR_ATTACHMENT0) + @as(c_uint, @intCast(i))),
                gl.GL_TEXTURE_2D,
                fb.color_textures[i],
                0,
            );
        }

        // Set draw buffers for MRT
        if (fb.color_count > 0) {
            var draw_buffers: [MAX_COLOR_ATTACHMENTS]c_uint = undefined;
            for (0..fb.color_count) |i| {
                draw_buffers[i] = @intCast(@as(c_uint, gl.GL_COLOR_ATTACHMENT0) + @as(c_uint, @intCast(i)));
            }
            gl.glDrawBuffers(@intCast(fb.color_count), &draw_buffers);
        } else {
            // Depth-only: no color output
            gl.glDrawBuffer(gl.GL_NONE);
            gl.glReadBuffer(gl.GL_NONE);
        }

        // Create depth/stencil attachment
        if (config.has_depth_stencil) {
            if (config.depth_as_texture) {
                gl.glGenTextures(1, &fb.depth_texture);
                if (fb.depth_texture == 0) {
                    fb.cleanup();
                    return FramebufferError.FramebufferCreationFailed;
                }
                gl.glBindTexture(gl.GL_TEXTURE_2D, fb.depth_texture);
                gl.glTexImage2D(
                    gl.GL_TEXTURE_2D,
                    0,
                    gl.GL_DEPTH_COMPONENT24,
                    config.width,
                    config.height,
                    0,
                    gl.GL_DEPTH_COMPONENT,
                    gl.GL_FLOAT,
                    null,
                );
                gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST);
                gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);
                gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_BORDER);
                gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_BORDER);
                const border_color = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
                gl.glTexParameterfv(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_BORDER_COLOR, &border_color);
                gl.glFramebufferTexture2D(gl.GL_FRAMEBUFFER, gl.GL_DEPTH_ATTACHMENT, gl.GL_TEXTURE_2D, fb.depth_texture, 0);
            } else {
                gl.glGenRenderbuffers(1, &fb.depth_renderbuffer);
                if (fb.depth_renderbuffer == 0) {
                    fb.cleanup();
                    return FramebufferError.RenderbufferCreationFailed;
                }
                gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, fb.depth_renderbuffer);
                gl.glRenderbufferStorage(gl.GL_RENDERBUFFER, gl.GL_DEPTH24_STENCIL8, config.width, config.height);
                gl.glFramebufferRenderbuffer(gl.GL_FRAMEBUFFER, gl.GL_DEPTH_STENCIL_ATTACHMENT, gl.GL_RENDERBUFFER, fb.depth_renderbuffer);
            }
        }

        // Check framebuffer completeness
        const status = gl.glCheckFramebufferStatus(gl.GL_FRAMEBUFFER);
        if (status != gl.GL_FRAMEBUFFER_COMPLETE) {
            fb.cleanup();
            return FramebufferError.FramebufferIncomplete;
        }

        // Unbind
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);
        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
        gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, 0);

        return fb;
    }

    fn cleanup(self: *Framebuffer) void {
        if (self.depth_texture != 0) {
            gl.glDeleteTextures(1, &self.depth_texture);
            self.depth_texture = 0;
        }
        if (self.depth_renderbuffer != 0) {
            gl.glDeleteRenderbuffers(1, &self.depth_renderbuffer);
            self.depth_renderbuffer = 0;
        }
        for (0..self.color_count) |i| {
            if (self.color_textures[i] != 0) {
                gl.glDeleteTextures(1, &self.color_textures[i]);
                self.color_textures[i] = 0;
            }
        }
        if (self.id != 0) {
            gl.glDeleteFramebuffers(1, &self.id);
            self.id = 0;
        }
    }

    pub fn deinit(self: *Framebuffer) void {
        self.cleanup();
    }

    pub fn bind(self: Framebuffer) void {
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.id);
        gl.glViewport(0, 0, self.width, self.height);
    }

    pub fn unbind() void {
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);
    }

    pub fn getColorTextureAt(self: Framebuffer, index: u32) u32 {
        if (index < self.color_count) {
            return self.color_textures[index];
        }
        return 0;
    }

    pub fn getDepthTexture(self: Framebuffer) u32 {
        return self.depth_texture;
    }

    pub fn bindColorTexture(self: Framebuffer, attachment_index: u32, texture_unit: u32) void {
        if (attachment_index < self.color_count) {
            gl.glActiveTexture(@intCast(@as(c_uint, gl.GL_TEXTURE0) + texture_unit));
            gl.glBindTexture(gl.GL_TEXTURE_2D, self.color_textures[attachment_index]);
        }
    }

    pub fn bindDepthTexture(self: Framebuffer, texture_unit: u32) void {
        if (self.depth_texture != 0) {
            gl.glActiveTexture(@intCast(@as(c_uint, gl.GL_TEXTURE0) + texture_unit));
            gl.glBindTexture(gl.GL_TEXTURE_2D, self.depth_texture);
        }
    }

    pub fn resize(self: *Framebuffer, width: i32, height: i32) FramebufferError!void {
        if (width == self.width and height == self.height) {
            return;
        }

        self.width = width;
        self.height = height;

        for (0..self.color_count) |i| {
            const fmt = self.color_formats[i];
            gl.glBindTexture(gl.GL_TEXTURE_2D, self.color_textures[i]);
            gl.glTexImage2D(
                gl.GL_TEXTURE_2D,
                0,
                fmt.glInternalFormat(),
                width,
                height,
                0,
                fmt.glFormat(),
                fmt.glType(),
                null,
            );
        }

        if (self.has_depth_stencil) {
            if (self.depth_as_texture) {
                gl.glBindTexture(gl.GL_TEXTURE_2D, self.depth_texture);
                gl.glTexImage2D(
                    gl.GL_TEXTURE_2D,
                    0,
                    gl.GL_DEPTH_COMPONENT24,
                    width,
                    height,
                    0,
                    gl.GL_DEPTH_COMPONENT,
                    gl.GL_FLOAT,
                    null,
                );
            } else {
                gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, self.depth_renderbuffer);
                gl.glRenderbufferStorage(gl.GL_RENDERBUFFER, gl.GL_DEPTH24_STENCIL8, width, height);
            }
        }

        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
        gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, 0);

        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.id);
        const status = gl.glCheckFramebufferStatus(gl.GL_FRAMEBUFFER);
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);

        if (status != gl.GL_FRAMEBUFFER_COMPLETE) {
            return FramebufferError.FramebufferIncomplete;
        }
    }

    pub fn readPixel(self: Framebuffer, x: i32, y: i32) [4]u8 {
        var pixel: [4]u8 = .{ 0, 0, 0, 0 };
        gl.glBindFramebuffer(gl.GL_READ_FRAMEBUFFER, self.id);
        gl.glReadPixels(x, y, 1, 1, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, @ptrCast(&pixel));
        gl.glBindFramebuffer(gl.GL_READ_FRAMEBUFFER, 0);
        return pixel;
    }
};
