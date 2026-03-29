const std = @import("std");
const Framebuffer = @import("../graphics/opengl_framebuffer.zig").Framebuffer;
const FramebufferConfig = @import("../graphics/opengl_framebuffer.zig").FramebufferConfig;
const AttachmentFormat = @import("../graphics/opengl_framebuffer.zig").AttachmentFormat;
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const fullscreen_quad = @import("../graphics/fullscreen_quad.zig");
const c = @import("../c.zig");
const gl = c.glad;

pub const PostProcessError = error{
    ShaderCreationFailed,
    FramebufferCreationFailed,
    OutOfMemory,
};

pub const PostProcessPipeline = struct {
    allocator: std.mem.Allocator,

    // HDR scene framebuffer (scene renders into this)
    hdr_framebuffer: Framebuffer,

    // Bloom resources
    bloom_enabled: bool,
    bloom_threshold_shader: Shader,
    blur_shader: Shader,
    bloom_composite_shader: Shader,
    tonemap_shader: Shader,
    bloom_threshold_fb: Framebuffer,
    blur_ping_fb: Framebuffer,
    blur_pong_fb: Framebuffer,
    bloom_iterations: u32,

    // Settings
    exposure: f32,
    gamma: f32,
    bloom_strength: f32,
    bloom_threshold: f32,

    width: i32,
    height: i32,

    const pp_vs = @embedFile("../graphics/shaders/postprocess_vertex.glsl");
    const tonemap_fs = @embedFile("../graphics/shaders/tonemap_fragment.glsl");
    const bloom_threshold_fs = @embedFile("../graphics/shaders/bloom_threshold_fragment.glsl");
    const blur_fs = @embedFile("../graphics/shaders/blur_fragment.glsl");
    const bloom_composite_fs = @embedFile("../graphics/shaders/bloom_composite_fragment.glsl");

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32) PostProcessError!PostProcessPipeline {
        const hdr_config = FramebufferConfig{
            .width = width,
            .height = height,
            .color_formats = &.{.rgba16f},
            .has_depth_stencil = true,
        };

        const bloom_config = FramebufferConfig{
            .width = width,
            .height = height,
            .color_formats = &.{.rgba16f},
            .has_depth_stencil = false,
        };

        const hdr_fb = Framebuffer.initWithConfig(hdr_config) catch {
            return PostProcessError.FramebufferCreationFailed;
        };

        const bloom_threshold_fb = Framebuffer.initWithConfig(bloom_config) catch {
            return PostProcessError.FramebufferCreationFailed;
        };

        const blur_ping_fb = Framebuffer.initWithConfig(bloom_config) catch {
            return PostProcessError.FramebufferCreationFailed;
        };

        const blur_pong_fb = Framebuffer.initWithConfig(bloom_config) catch {
            return PostProcessError.FramebufferCreationFailed;
        };

        const tonemap_shader = Shader.init(allocator, pp_vs, tonemap_fs) catch {
            return PostProcessError.ShaderCreationFailed;
        };

        const bloom_threshold_shader = Shader.init(allocator, pp_vs, bloom_threshold_fs) catch {
            return PostProcessError.ShaderCreationFailed;
        };

        const blur_shader = Shader.init(allocator, pp_vs, blur_fs) catch {
            return PostProcessError.ShaderCreationFailed;
        };

        const bloom_composite_shader = Shader.init(allocator, pp_vs, bloom_composite_fs) catch {
            return PostProcessError.ShaderCreationFailed;
        };

        return .{
            .allocator = allocator,
            .hdr_framebuffer = hdr_fb,
            .bloom_enabled = false,
            .bloom_threshold_shader = bloom_threshold_shader,
            .blur_shader = blur_shader,
            .bloom_composite_shader = bloom_composite_shader,
            .tonemap_shader = tonemap_shader,
            .bloom_threshold_fb = bloom_threshold_fb,
            .blur_ping_fb = blur_ping_fb,
            .blur_pong_fb = blur_pong_fb,
            .bloom_iterations = 5,
            .exposure = 1.0,
            .gamma = 2.2,
            .bloom_strength = 0.3,
            .bloom_threshold = 1.0,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *PostProcessPipeline) void {
        self.hdr_framebuffer.deinit();
        self.bloom_threshold_fb.deinit();
        self.blur_ping_fb.deinit();
        self.blur_pong_fb.deinit();
        self.tonemap_shader.deinit();
        self.bloom_threshold_shader.deinit();
        self.blur_shader.deinit();
        self.bloom_composite_shader.deinit();
    }

    pub fn getHdrFramebuffer(self: *PostProcessPipeline) *Framebuffer {
        return &self.hdr_framebuffer;
    }

    pub fn beginScene(self: *PostProcessPipeline) void {
        self.hdr_framebuffer.bind();
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
    }

    pub fn endScene(_: *PostProcessPipeline) void {
        Framebuffer.unbind();
    }

    pub fn render(self: *PostProcessPipeline) void {
        gl.glDisable(gl.GL_DEPTH_TEST);

        if (self.bloom_enabled) {
            self.renderBloom();
        } else {
            self.renderTonemap();
        }

        gl.glEnable(gl.GL_DEPTH_TEST);
    }

    fn renderTonemap(self: *PostProcessPipeline) void {
        self.tonemap_shader.bind();
        self.tonemap_shader.setUniform("u_screenTexture", @as(i32, 0));
        self.tonemap_shader.setUniform("u_exposure", self.exposure);
        self.tonemap_shader.setUniform("u_gamma", self.gamma);

        gl.glActiveTexture(gl.GL_TEXTURE0);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.hdr_framebuffer.getColorTexture());

        fullscreen_quad.draw();
    }

    fn renderBloom(self: *PostProcessPipeline) void {
        // Step 1: Extract bright pixels
        self.bloom_threshold_fb.bind();
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        self.bloom_threshold_shader.bind();
        self.bloom_threshold_shader.setUniform("u_screenTexture", @as(i32, 0));
        self.bloom_threshold_shader.setUniform("u_threshold", self.bloom_threshold);

        gl.glActiveTexture(gl.GL_TEXTURE0);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.hdr_framebuffer.getColorTexture());
        fullscreen_quad.draw();
        Framebuffer.unbind();

        // Step 2: Gaussian blur (ping-pong)
        self.blur_shader.bind();
        self.blur_shader.setUniform("u_image", @as(i32, 0));

        var horizontal: bool = true;
        var first_iteration: bool = true;

        for (0..self.bloom_iterations * 2) |_| {
            if (horizontal) {
                self.blur_ping_fb.bind();
            } else {
                self.blur_pong_fb.bind();
            }
            gl.glClear(gl.GL_COLOR_BUFFER_BIT);

            self.blur_shader.setUniform("u_horizontal", @as(i32, if (horizontal) 1 else 0));

            gl.glActiveTexture(gl.GL_TEXTURE0);
            if (first_iteration) {
                gl.glBindTexture(gl.GL_TEXTURE_2D, self.bloom_threshold_fb.getColorTexture());
                first_iteration = false;
            } else if (horizontal) {
                gl.glBindTexture(gl.GL_TEXTURE_2D, self.blur_pong_fb.getColorTexture());
            } else {
                gl.glBindTexture(gl.GL_TEXTURE_2D, self.blur_ping_fb.getColorTexture());
            }

            fullscreen_quad.draw();
            Framebuffer.unbind();

            horizontal = !horizontal;
        }

        // Step 3: Composite bloom + tonemap
        self.bloom_composite_shader.bind();
        self.bloom_composite_shader.setUniform("u_screenTexture", @as(i32, 0));
        self.bloom_composite_shader.setUniform("u_bloomTexture", @as(i32, 1));
        self.bloom_composite_shader.setUniform("u_bloomStrength", self.bloom_strength);
        self.bloom_composite_shader.setUniform("u_exposure", self.exposure);
        self.bloom_composite_shader.setUniform("u_gamma", self.gamma);

        gl.glActiveTexture(gl.GL_TEXTURE0);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.hdr_framebuffer.getColorTexture());
        gl.glActiveTexture(gl.GL_TEXTURE1);
        // Use the last written blur buffer
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.blur_ping_fb.getColorTexture());

        fullscreen_quad.draw();
    }

    pub fn resize(self: *PostProcessPipeline, width: i32, height: i32) void {
        if (width == self.width and height == self.height) return;
        self.width = width;
        self.height = height;

        self.hdr_framebuffer.resize(width, height) catch {};
        self.bloom_threshold_fb.resize(width, height) catch {};
        self.blur_ping_fb.resize(width, height) catch {};
        self.blur_pong_fb.resize(width, height) catch {};
    }

    pub fn setExposure(self: *PostProcessPipeline, exposure: f32) void {
        self.exposure = exposure;
    }

    pub fn setGamma(self: *PostProcessPipeline, gamma: f32) void {
        self.gamma = gamma;
    }

    pub fn setBloomEnabled(self: *PostProcessPipeline, enabled: bool) void {
        self.bloom_enabled = enabled;
    }

    pub fn setBloomStrength(self: *PostProcessPipeline, strength: f32) void {
        self.bloom_strength = strength;
    }

    pub fn setBloomThreshold(self: *PostProcessPipeline, threshold: f32) void {
        self.bloom_threshold = threshold;
    }

    pub fn setBloomIterations(self: *PostProcessPipeline, iterations: u32) void {
        self.bloom_iterations = iterations;
    }
};
