const std = @import("std");
const zimp = @import("zimp");
const c = @import("../c.zig");
const gl = c.glad;

const Shader = @import("opengl/shader.zig").Shader;
const Texture2D = @import("opengl/texture.zig").Texture2D;

pub const Material = struct {
    shader: Shader,
    source: zimp.Zamat,
    texture_bindings: []TextureBinding,
    param_bindings: []ParamBinding,
    allocator: std.mem.Allocator,

    const TextureBinding = struct {
        unit: u16,
        texture: Texture2D,
        slot_name_hash: u64,
    };

    const ParamBinding = struct {
        param_index: usize,
        location: i32,
    };

    pub fn load(
        allocator: std.mem.Allocator,
        io: std.Io,
        dir: std.Io.Dir,
        path: []const u8,
    ) !Material {
        const file = try dir.openFile(io, path, .{});
        defer file.close(io);

        var buf: [8192]u8 = undefined;
        var reader_state = file.reader(io, &buf);
        const source = try zimp.Zamat.read(allocator, &reader_state.interface);
        errdefer {
            var tmp = source;
            tmp.deinit(allocator);
        }

        const base_dir = std.fs.path.dirname(path);

        const vertex_shader_path = try materialRelativePath(allocator, base_dir, source.vertex_shader_path);
        defer allocator.free(vertex_shader_path);
        const fragment_shader_path = try materialRelativePath(allocator, base_dir, source.fragment_shader_path);
        defer allocator.free(fragment_shader_path);

        var shader = try loadShader(allocator, io, dir, vertex_shader_path, fragment_shader_path);
        errdefer shader.deinit();

        var texture_bindings = std.ArrayList(TextureBinding).empty;
        errdefer {
            for (texture_bindings.items) |*binding| binding.texture.deinit();
            texture_bindings.deinit(allocator);
        }

        for (source.texture_slots) |slot| {
            if (slot.slot_index == std.math.maxInt(u16)) {
                continue;
            }
            if (slot.cooked_path.len == 0) {
                continue;
            }

            const texture_path = try materialRelativePath(allocator, base_dir, slot.cooked_path);
            defer allocator.free(texture_path);

            var texture = try loadTexture(allocator, io, dir, texture_path);
            errdefer texture.deinit();

            try texture_bindings.append(allocator, .{
                .unit = slot.slot_index,
                .texture = texture,
                .slot_name_hash = slot.slot_name_hash,
            });
        }

        var param_bindings = std.ArrayList(ParamBinding).empty;
        errdefer param_bindings.deinit(allocator);

        for (source.param_entries, 0..) |param, i| {
            const location = shader.uniformLocation(param.name) orelse continue;
            try param_bindings.append(allocator, .{
                .param_index = i,
                .location = location,
            });
        }

        const texture_slice = try texture_bindings.toOwnedSlice(allocator);
        errdefer {
            for (texture_slice) |*binding| binding.texture.deinit();
            allocator.free(texture_slice);
        }
        const param_slice = try param_bindings.toOwnedSlice(allocator);

        return .{
            .shader = shader,
            .source = source,
            .texture_bindings = texture_slice,
            .param_bindings = param_slice,
            .allocator = allocator,
        };
    }

    pub fn bind(self: *const Material) void {
        self.shader.bind();
        applyAlphaMode(self.source.alpha_mode);

        for (self.texture_bindings) |*binding| {
            binding.texture.bind(binding.unit);
            if (samplerUniformName(binding.slot_name_hash)) |name| {
                self.shader.setUniform(name, @as(i32, @intCast(binding.unit)));
            }
        }

        for (self.param_bindings) |binding| {
            const param = self.source.param_entries[binding.param_index];
            const start: usize = param.data_offset;
            const end = start + param.data_size;
            if (end > self.source.param_data.len) {
                continue;
            }
            const bytes = self.source.param_data[start..end];

            switch (param.param_type) {
                .float => gl.glUniform1f(binding.location, readF32(bytes[0..4])),
                .vec2 => gl.glUniform2f(
                    binding.location,
                    readF32(bytes[0..4]),
                    readF32(bytes[4..8]),
                ),
                .vec3 => gl.glUniform3f(
                    binding.location,
                    readF32(bytes[0..4]),
                    readF32(bytes[4..8]),
                    readF32(bytes[8..12]),
                ),
                .vec4 => gl.glUniform4f(
                    binding.location,
                    readF32(bytes[0..4]),
                    readF32(bytes[4..8]),
                    readF32(bytes[8..12]),
                    readF32(bytes[12..16]),
                ),
                .int => gl.glUniform1i(
                    binding.location,
                    std.mem.readInt(i32, bytes[0..4], .little),
                ),
                .bool => gl.glUniform1i(binding.location, if (std.mem.readInt(u32, bytes[0..4], .little) != 0) 1 else 0),
            }
        }
    }

    pub fn setUniform(self: *const Material, name: []const u8, value: anytype) void {
        self.shader.setUniform(name, value);
    }

    pub fn deinit(self: *Material) void {
        for (self.texture_bindings) |*binding| {
            binding.texture.deinit();
        }
        self.allocator.free(self.texture_bindings);
        self.allocator.free(self.param_bindings);
        self.shader.deinit();
        self.source.deinit(self.allocator);
    }
};

fn materialRelativePath(allocator: std.mem.Allocator, base_dir: ?[]const u8, path: []const u8) ![]u8 {
    if (base_dir) |base| {
        return std.fs.path.join(allocator, &.{ base, path });
    }
    return allocator.dupe(u8, path);
}

fn loadShader(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    vertex_path: []const u8,
    fragment_path: []const u8,
) !Shader {
    const vertex_file = try dir.openFile(io, vertex_path, .{});
    defer vertex_file.close(io);
    var vertex_reader_buf: [8192]u8 = undefined;
    var vertex_reader = vertex_file.reader(io, &vertex_reader_buf);
    var vertex_shader = try zimp.ZShader.read(allocator, &vertex_reader.interface);
    defer vertex_shader.deinit(allocator);

    const fragment_file = try dir.openFile(io, fragment_path, .{});
    defer fragment_file.close(io);
    var fragment_reader_buf: [8192]u8 = undefined;
    var fragment_reader = fragment_file.reader(io, &fragment_reader_buf);
    var fragment_shader = try zimp.ZShader.read(allocator, &fragment_reader.interface);
    defer fragment_shader.deinit(allocator);

    const vertex_source = try vertex_shader.baseSource();
    const fragment_source = try fragment_shader.baseSource();
    return Shader.init(allocator, vertex_source.ptr, fragment_source.ptr);
}

fn loadTexture(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    path: []const u8,
) !Texture2D {
    const file = try dir.openFile(io, path, .{});
    defer file.close(io);

    var ztex = try zimp.Zatex.read(allocator, io, file);
    defer ztex.deinit(allocator);

    return Texture2D.init(ztex);
}

fn applyAlphaMode(mode: anytype) void {
    switch (mode) {
        .solid => {
            gl.glDisable(gl.GL_BLEND);
            gl.glDepthMask(gl.GL_TRUE);
        },
        .alpha_test => {
            gl.glDisable(gl.GL_BLEND);
            gl.glDepthMask(gl.GL_TRUE);
        },
        .alpha_blend => {
            gl.glEnable(gl.GL_BLEND);
            gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
            gl.glDepthMask(gl.GL_FALSE);
        },
    }
}

fn samplerUniformName(slot_hash: u64) ?[]const u8 {
    if (slot_hash == fnv1a("albedo")) return "u_albedo";
    if (slot_hash == fnv1a("normal")) return "u_normal_map";
    if (slot_hash == fnv1a("roughness")) return "u_roughness_map";
    if (slot_hash == fnv1a("metallic")) return "u_metallic_map";
    if (slot_hash == fnv1a("ao")) return "u_ao";
    if (slot_hash == fnv1a("emissive")) return "u_emissive_map";
    if (slot_hash == fnv1a("roughness_metallic")) return "u_roughness_metallic";
    if (slot_hash == fnv1a("orm")) return "u_orm";
    return null;
}

fn readF32(bytes: *const [4]u8) f32 {
    return @bitCast(std.mem.readInt(u32, bytes, .little));
}

fn fnv1a(bytes: []const u8) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    for (bytes) |byte| {
        const b: u8 = if (byte == '\\') '/' else byte;
        hash ^= b;
        hash *%= 0x00000100000001B3;
    }
    return hash;
}
