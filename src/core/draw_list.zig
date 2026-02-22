const std = @import("std");
const AssetManager = @import("../asset/manager.zig").AssetManager;
const Camera = @import("../scene/camera.zig").Camera;
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const MaterialInstance = @import("../asset/material.zig").MaterialInstance;
const Model = @import("../asset/model.zig").Model;
const ShadowMap = @import("shadow_map.zig").ShadowMap;
const math = @import("zlm").as(f32);
const c = @import("../c.zig");
const gl = c.glad;

pub const DrawCommand = struct {
    model_index: usize,
    sort_key: u64,
    depth: f32,
};

pub const DrawList = struct {
    commands: std.ArrayList(DrawCommand),
    allocator: std.mem.Allocator,
    shadow_map: ?*const ShadowMap = null,

    pub fn init(allocator: std.mem.Allocator) DrawList {
        return .{
            .commands = .empty,
            .allocator = allocator,
        };
    }

    pub fn setShadowMap(self: *DrawList, sm: ?*const ShadowMap) void {
        self.shadow_map = sm;
    }

    pub fn deinit(self: *DrawList) void {
        self.commands.deinit(self.allocator);
    }

    pub fn clear(self: *DrawList) void {
        self.commands.clearRetainingCapacity();
    }

    pub fn collectFromScene(self: *DrawList, camera: *Camera) !void {
        self.clear();

        const models = AssetManager.GetModels();
        const cam_pos = camera.position;

        for (models, 0..) |model, i| {
            const model_matrix = AssetManager.GetWorldMatrix(i);

            // Compute depth (distance from camera for sorting)
            const model_pos = math.Vec3{
                .x = model_matrix.fields[3][0],
                .y = model_matrix.fields[3][1],
                .z = model_matrix.fields[3][2],
            };
            const dx = model_pos.x - cam_pos.x;
            const dy = model_pos.y - cam_pos.y;
            const dz = model_pos.z - cam_pos.z;
            const depth = dx * dx + dy * dy + dz * dz;

            // Sort key: shader ID (high 32 bits) | material ptr hash (low 32 bits)
            const shader_id: u64 = @intCast(model.material.material.shader.id);
            const mat_addr: u64 = @intCast(@intFromPtr(model.material));
            const sort_key = (shader_id << 32) | (mat_addr & 0xFFFFFFFF);

            try self.commands.append(self.allocator, .{
                .model_index = i,
                .sort_key = sort_key,
                .depth = depth,
            });
        }
    }

    pub fn sortOpaque(self: *DrawList) void {
        std.mem.sort(DrawCommand, self.commands.items, {}, struct {
            fn lessThan(_: void, a: DrawCommand, b: DrawCommand) bool {
                // Primary: sort by shader/material (minimize state changes)
                if (a.sort_key != b.sort_key) return a.sort_key < b.sort_key;
                // Secondary: front-to-back (early depth rejection)
                return a.depth < b.depth;
            }
        }.lessThan);
    }

    pub fn sortTransparent(self: *DrawList) void {
        std.mem.sort(DrawCommand, self.commands.items, {}, struct {
            fn lessThan(_: void, a: DrawCommand, b: DrawCommand) bool {
                // Back-to-front for correct alpha blending
                return a.depth > b.depth;
            }
        }.lessThan);
    }

    pub fn execute(self: *DrawList, camera: *Camera) void {
        const models = AssetManager.GetModels();
        const lights = AssetManager.GetLights();
        var last_shader_id: u32 = 0;
        var last_material: ?*const MaterialInstance = null;

        for (self.commands.items) |cmd| {
            const model = models[cmd.model_index];
            const shader = model.material.material.shader;

            // Only rebind shader if it changed
            if (shader.id != last_shader_id) {
                shader.bind();
                last_shader_id = shader.id;

                // Upload lights once per shader change
                uploadLightsToShader(shader, lights);

                // Upload shadow uniforms once per shader change
                if (self.shadow_map) |sm| {
                    shader.setUniform("u_shadowEnabled", @as(i32, 1));
                    shader.setUniform("u_lightSpaceMatrix", sm.getLightSpaceMatrix());
                    shader.setUniform("u_shadowMap", @as(i32, 4));
                    gl.glActiveTexture(gl.GL_TEXTURE4);
                    gl.glBindTexture(gl.GL_TEXTURE_2D, sm.getDepthTexture());
                } else {
                    shader.setUniform("u_shadowEnabled", @as(i32, 0));
                }
            }

            // Only rebind material if it changed
            if (last_material != model.material) {
                last_material = model.material;

                shader.setUniform("material.ambient", model.material.lighting.ambient);
                shader.setUniform("material.diffuse", model.material.lighting.diffuse);
                shader.setUniform("material.specular", model.material.lighting.specular);
                shader.setUniform("material.shininess", model.material.lighting.shininess);

                if (model.material.hasTextures()) {
                    shader.setUniform("u_useTextures", @as(i32, 1));
                    shader.setUniform("u_baseColorTex", @as(i32, 0));
                    shader.setUniform("u_metalRoughTex", @as(i32, 1));
                    model.material.bindTextures();
                }
            }

            // Per-draw uniforms (transform is always unique)
            const model_matrix = AssetManager.GetWorldMatrix(cmd.model_index);
            shader.setUniform("r_position", model_matrix.mul(camera.viewProjectionMatrix()));
            shader.setUniform("r_viewPos", camera.position);
            shader.setUniform("r_model", model_matrix);

            model.draw();
        }
    }

    fn uploadLightsToShader(shader: *const Shader, lights: []const @import("../asset/light.zig").Light) void {
        const count: i32 = @intCast(@min(lights.len, 16));
        shader.setUniform("numLights", count);

        for (lights[0..@intCast(count)], 0..) |light, i| {
            var buf: [64]u8 = undefined;
            const prefix = std.fmt.bufPrint(&buf, "lights[{d}].", .{i}) catch continue;
            const p = prefix.len;

            setField(shader, &buf, p, "kind", @as(i32, @intFromEnum(light.kind)));
            setField(shader, &buf, p, "position", light.position);
            setField(shader, &buf, p, "direction", light.direction);
            setField(shader, &buf, p, "ambient", light.ambient);
            setField(shader, &buf, p, "diffuse", light.diffuse);
            setField(shader, &buf, p, "specular", light.specular);
            setField(shader, &buf, p, "constant", light.constant);
            setField(shader, &buf, p, "linear", light.linear);
            setField(shader, &buf, p, "quadratic", light.quadratic);
            setField(shader, &buf, p, "cutOff", light.cut_off);
            setField(shader, &buf, p, "outerCutOff", light.outer_cut_off);
        }
    }

    fn setField(shader: *const Shader, buf: *[64]u8, prefix_len: usize, field: []const u8, value: anytype) void {
        @memcpy(buf[prefix_len .. prefix_len + field.len], field);
        shader.setUniform(buf[0 .. prefix_len + field.len], value);
    }
};
