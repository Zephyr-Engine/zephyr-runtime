const std = @import("std");
const Framebuffer = @import("../graphics/opengl_framebuffer.zig").Framebuffer;
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const fullscreen_quad = @import("../graphics/fullscreen_quad.zig");
const c = @import("../c.zig");
const gl = c.glad;
const math = @import("zlm").as(f32);

pub const ClearFlags = packed struct {
    color: bool = false,
    depth: bool = false,
    stencil: bool = false,
};

pub const RenderPass = struct {
    name: []const u8,
    target: ?*Framebuffer,
    clear_flags: ClearFlags,
    clear_color: [4]f32,
    depth_test: bool,
    blend: bool,
    input_textures: [MAX_INPUT_TEXTURES]InputTexture,
    input_count: u32,
    draw_fn: ?*const fn (*RenderPass) void,
    user_data: ?*anyopaque,

    const MAX_INPUT_TEXTURES = 8;

    pub const InputTexture = struct {
        texture_id: u32 = 0,
        unit: u32 = 0,
        uniform_name: []const u8 = "",
    };

    pub fn init(name: []const u8) RenderPass {
        return .{
            .name = name,
            .target = null,
            .clear_flags = .{ .color = true, .depth = true },
            .clear_color = .{ 0.0, 0.0, 0.0, 1.0 },
            .depth_test = true,
            .blend = false,
            .input_textures = [_]InputTexture{.{}} ** MAX_INPUT_TEXTURES,
            .input_count = 0,
            .draw_fn = null,
            .user_data = null,
        };
    }

    pub fn setTarget(self: *RenderPass, fb: *Framebuffer) *RenderPass {
        self.target = fb;
        return self;
    }

    pub fn setClearColor(self: *RenderPass, r: f32, g: f32, b: f32, a: f32) *RenderPass {
        self.clear_color = .{ r, g, b, a };
        return self;
    }

    pub fn setClearFlags(self: *RenderPass, flags: ClearFlags) *RenderPass {
        self.clear_flags = flags;
        return self;
    }

    pub fn setDepthTest(self: *RenderPass, enabled: bool) *RenderPass {
        self.depth_test = enabled;
        return self;
    }

    pub fn setBlend(self: *RenderPass, enabled: bool) *RenderPass {
        self.blend = enabled;
        return self;
    }

    pub fn addInputTexture(self: *RenderPass, texture_id: u32, unit: u32, uniform_name: []const u8) *RenderPass {
        if (self.input_count < MAX_INPUT_TEXTURES) {
            self.input_textures[self.input_count] = .{
                .texture_id = texture_id,
                .unit = unit,
                .uniform_name = uniform_name,
            };
            self.input_count += 1;
        }
        return self;
    }

    pub fn setDrawFn(self: *RenderPass, func: *const fn (*RenderPass) void) *RenderPass {
        self.draw_fn = func;
        return self;
    }

    pub fn setUserData(self: *RenderPass, data: *anyopaque) *RenderPass {
        self.user_data = data;
        return self;
    }

    pub fn getUserData(self: *RenderPass, comptime T: type) ?*T {
        if (self.user_data) |ptr| {
            return @ptrCast(@alignCast(ptr));
        }
        return null;
    }

    pub fn execute(self: *RenderPass) void {
        // Bind render target
        if (self.target) |fb| {
            fb.bind();
        } else {
            gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);
        }

        // Clear
        var gl_clear_bits: u32 = 0;
        if (self.clear_flags.color) {
            gl.glClearColor(self.clear_color[0], self.clear_color[1], self.clear_color[2], self.clear_color[3]);
            gl_clear_bits |= gl.GL_COLOR_BUFFER_BIT;
        }
        if (self.clear_flags.depth) {
            gl_clear_bits |= gl.GL_DEPTH_BUFFER_BIT;
        }
        if (self.clear_flags.stencil) {
            gl_clear_bits |= gl.GL_STENCIL_BUFFER_BIT;
        }
        if (gl_clear_bits != 0) {
            gl.glClear(gl_clear_bits);
        }

        // Depth test
        if (self.depth_test) {
            gl.glEnable(gl.GL_DEPTH_TEST);
        } else {
            gl.glDisable(gl.GL_DEPTH_TEST);
        }

        // Blending
        if (self.blend) {
            gl.glEnable(gl.GL_BLEND);
            gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
        } else {
            gl.glDisable(gl.GL_BLEND);
        }

        // Bind input textures
        for (self.input_textures[0..self.input_count]) |input| {
            gl.glActiveTexture(@intCast(@as(c_uint, gl.GL_TEXTURE0) + input.unit));
            gl.glBindTexture(gl.GL_TEXTURE_2D, input.texture_id);
        }

        // Execute draw function
        if (self.draw_fn) |func| {
            func(self);
        }

        // Unbind target
        if (self.target != null) {
            Framebuffer.unbind();
        }
    }
};

pub const RenderPipeline = struct {
    passes: std.BoundedArray(RenderPass, MAX_PASSES),
    viewport_width: i32,
    viewport_height: i32,

    const MAX_PASSES = 16;

    pub fn init(viewport_width: i32, viewport_height: i32) RenderPipeline {
        return .{
            .passes = std.BoundedArray(RenderPass, MAX_PASSES){},
            .viewport_width = viewport_width,
            .viewport_height = viewport_height,
        };
    }

    pub fn addPass(self: *RenderPipeline, pass: RenderPass) *RenderPass {
        self.passes.append(pass) catch return &self.passes.buffer[self.passes.len - 1];
        return &self.passes.buffer[self.passes.len - 1];
    }

    pub fn clear(self: *RenderPipeline) void {
        self.passes.len = 0;
    }

    pub fn execute(self: *RenderPipeline) void {
        for (self.passes.slice()) |*pass| {
            pass.execute();
        }

        // Restore default viewport after all passes
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);
        gl.glViewport(0, 0, self.viewport_width, self.viewport_height);
    }

    pub fn setViewport(self: *RenderPipeline, width: i32, height: i32) void {
        self.viewport_width = width;
        self.viewport_height = height;
    }
};
