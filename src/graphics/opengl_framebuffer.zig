const c = @import("../c.zig");
const gl = c.glad;

pub const FramebufferError = error{
    FramebufferCreationFailed,
    RenderbufferCreationFailed,
    FramebufferIncomplete,
    OpenGLError,
};

pub const Framebuffer = struct {
    id: u32,
    color_texture: u32,
    depth_renderbuffer: u32,
    width: i32,
    height: i32,

    pub fn init(width: i32, height: i32) FramebufferError!Framebuffer {
        var fb = Framebuffer{
            .id = 0,
            .color_texture = 0,
            .depth_renderbuffer = 0,
            .width = width,
            .height = height,
        };

        // Create framebuffer
        gl.glGenFramebuffers(1, &fb.id);
        if (fb.id == 0) {
            return FramebufferError.FramebufferCreationFailed;
        }
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, fb.id);

        // Create color texture attachment
        gl.glGenTextures(1, &fb.color_texture);
        if (fb.color_texture == 0) {
            gl.glDeleteFramebuffers(1, &fb.id);
            return FramebufferError.FramebufferCreationFailed;
        }

        gl.glBindTexture(gl.GL_TEXTURE_2D, fb.color_texture);
        gl.glTexImage2D(
            gl.GL_TEXTURE_2D,
            0,
            gl.GL_RGBA8,
            width,
            height,
            0,
            gl.GL_RGBA,
            gl.GL_UNSIGNED_BYTE,
            null,
        );
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
        gl.glFramebufferTexture2D(gl.GL_FRAMEBUFFER, gl.GL_COLOR_ATTACHMENT0, gl.GL_TEXTURE_2D, fb.color_texture, 0);

        // Create depth renderbuffer
        gl.glGenRenderbuffers(1, &fb.depth_renderbuffer);
        if (fb.depth_renderbuffer == 0) {
            gl.glDeleteTextures(1, &fb.color_texture);
            gl.glDeleteFramebuffers(1, &fb.id);
            return FramebufferError.RenderbufferCreationFailed;
        }

        gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, fb.depth_renderbuffer);
        gl.glRenderbufferStorage(gl.GL_RENDERBUFFER, gl.GL_DEPTH24_STENCIL8, width, height);
        gl.glFramebufferRenderbuffer(gl.GL_FRAMEBUFFER, gl.GL_DEPTH_STENCIL_ATTACHMENT, gl.GL_RENDERBUFFER, fb.depth_renderbuffer);

        // Check framebuffer completeness
        const status = gl.glCheckFramebufferStatus(gl.GL_FRAMEBUFFER);
        if (status != gl.GL_FRAMEBUFFER_COMPLETE) {
            fb.cleanup();
            return FramebufferError.FramebufferIncomplete;
        }

        // Unbind framebuffer
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);
        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
        gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, 0);

        return fb;
    }

    fn cleanup(self: *Framebuffer) void {
        if (self.depth_renderbuffer != 0) {
            gl.glDeleteRenderbuffers(1, &self.depth_renderbuffer);
            self.depth_renderbuffer = 0;
        }
        if (self.color_texture != 0) {
            gl.glDeleteTextures(1, &self.color_texture);
            self.color_texture = 0;
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

    pub fn resize(self: *Framebuffer, width: i32, height: i32) FramebufferError!void {
        if (width == self.width and height == self.height) {
            return;
        }

        self.width = width;
        self.height = height;

        // Resize color texture
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.color_texture);
        gl.glTexImage2D(
            gl.GL_TEXTURE_2D,
            0,
            gl.GL_RGBA8,
            width,
            height,
            0,
            gl.GL_RGBA,
            gl.GL_UNSIGNED_BYTE,
            null,
        );

        // Resize depth renderbuffer
        gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, self.depth_renderbuffer);
        gl.glRenderbufferStorage(gl.GL_RENDERBUFFER, gl.GL_DEPTH24_STENCIL8, width, height);

        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
        gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, 0);

        // Verify framebuffer is still complete
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.id);
        const status = gl.glCheckFramebufferStatus(gl.GL_FRAMEBUFFER);
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);

        if (status != gl.GL_FRAMEBUFFER_COMPLETE) {
            return FramebufferError.FramebufferIncomplete;
        }
    }

    pub fn getColorTexture(self: Framebuffer) u32 {
        return self.color_texture;
    }
};
