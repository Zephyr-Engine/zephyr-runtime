const c = @import("../../c.zig");
const gl = c.glad;

pub const FramebufferError = error{
    FramebufferCreationFailed,
    TextureCreationFailed,
    RenderbufferCreationFailed,
    FramebufferIncomplete,
};

const Framebuffer = @This();

id: u32 = 0,
color_texture: u32 = 0,
depth_stencil: u32 = 0,
width: u32 = 0,
height: u32 = 0,

pub fn init(width: u32, height: u32) FramebufferError!Framebuffer {
    var self: Framebuffer = .{};
    errdefer self.deinit();
    try self.resize(width, height);
    return self;
}

pub fn deinit(self: *Framebuffer) void {
    self.destroyAttachments();
    if (self.id != 0) {
        gl.glDeleteFramebuffers(1, &self.id);
        self.id = 0;
    }
    self.width = 0;
    self.height = 0;
}

pub fn resize(self: *Framebuffer, width: u32, height: u32) FramebufferError!void {
    const target_width = @max(1, width);
    const target_height = @max(1, height);
    if (self.id != 0 and self.width == target_width and self.height == target_height) {
        return;
    }

    if (self.id == 0) {
        gl.glGenFramebuffers(1, &self.id);
        if (self.id == 0) return FramebufferError.FramebufferCreationFailed;
    }

    self.width = target_width;
    self.height = target_height;

    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.id);
    errdefer gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);

    if (self.color_texture == 0) {
        gl.glGenTextures(1, &self.color_texture);
        if (self.color_texture == 0) return FramebufferError.TextureCreationFailed;
        errdefer {
            gl.glDeleteTextures(1, &self.color_texture);
            self.color_texture = 0;
        }
    }

    gl.glBindTexture(gl.GL_TEXTURE_2D, self.color_texture);
    gl.glTexImage2D(
        gl.GL_TEXTURE_2D,
        0,
        gl.GL_RGBA8,
        @intCast(target_width),
        @intCast(target_height),
        0,
        gl.GL_RGBA,
        gl.GL_UNSIGNED_BYTE,
        null,
    );
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
    gl.glFramebufferTexture2D(
        gl.GL_FRAMEBUFFER,
        gl.GL_COLOR_ATTACHMENT0,
        gl.GL_TEXTURE_2D,
        self.color_texture,
        0,
    );

    if (self.depth_stencil == 0) {
        gl.glGenRenderbuffers(1, &self.depth_stencil);
        if (self.depth_stencil == 0) {
            return FramebufferError.RenderbufferCreationFailed;
        }

        errdefer {
            gl.glDeleteRenderbuffers(1, &self.depth_stencil);
            self.depth_stencil = 0;
        }
    }

    gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, self.depth_stencil);
    gl.glRenderbufferStorage(
        gl.GL_RENDERBUFFER,
        gl.GL_DEPTH24_STENCIL8,
        @intCast(target_width),
        @intCast(target_height),
    );
    gl.glFramebufferRenderbuffer(
        gl.GL_FRAMEBUFFER,
        gl.GL_DEPTH_STENCIL_ATTACHMENT,
        gl.GL_RENDERBUFFER,
        self.depth_stencil,
    );

    if (gl.glCheckFramebufferStatus(gl.GL_FRAMEBUFFER) != gl.GL_FRAMEBUFFER_COMPLETE) {
        return FramebufferError.FramebufferIncomplete;
    }

    gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, 0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);
}

pub fn bind(self: *const Framebuffer) void {
    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.id);
    gl.glViewport(0, 0, @intCast(self.width), @intCast(self.height));
}

pub fn textureId(self: *const Framebuffer) u32 {
    return self.color_texture;
}

fn destroyAttachments(self: *Framebuffer) void {
    if (self.depth_stencil != 0) {
        gl.glDeleteRenderbuffers(1, &self.depth_stencil);
        self.depth_stencil = 0;
    }
    if (self.color_texture != 0) {
        gl.glDeleteTextures(1, &self.color_texture);
        self.color_texture = 0;
    }
}

pub fn bindDefault(width: u32, height: u32) void {
    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);
    gl.glViewport(0, 0, @intCast(@max(1, width)), @intCast(@max(1, height)));
}
