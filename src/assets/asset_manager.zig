const std = @import("std");
const zimp = @import("zimp");

const asset_id = @import("id.zig");
const asset_path = @import("path.zig");
const loaders = @import("loaders.zig");
const source_mod = @import("source.zig");

const AssetKind = asset_id.AssetKind;
const AssetRoots = source_mod.AssetRoots;
const AssetSource = source_mod.AssetSource;
const AssetError = source_mod.AssetError;
const FileSource = source_mod.FileSource;
const Mesh = @import("../graphics/mesh.zig").Mesh;
const Material = @import("../graphics/material.zig").Material;
const Shader = @import("../graphics/opengl/shader.zig").Shader;
const Texture2D = @import("../graphics/opengl/texture.zig").Texture2D;

pub const ShaderProgramKey = struct {
    vertex_path: []const u8,
    fragment_path: []const u8,
    hash: u64,
};

pub const AssetManager = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    source: AssetSource,

    meshes: std.StringHashMap(*Mesh),
    materials: std.StringHashMap(*Material),
    textures: std.StringHashMap(*Texture2D),
    shader_programs: std.StringHashMap(*Shader),

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        source: AssetSource,
    ) AssetManager {
        return .{
            .allocator = allocator,
            .io = io,
            .source = source,
            .meshes = std.StringHashMap(*Mesh).init(allocator),
            .materials = std.StringHashMap(*Material).init(allocator),
            .textures = std.StringHashMap(*Texture2D).init(allocator),
            .shader_programs = std.StringHashMap(*Shader).init(allocator),
        };
    }

    pub fn initFiles(
        allocator: std.mem.Allocator,
        io: std.Io,
        roots: AssetRoots,
    ) !AssetManager {
        const source = try FileSource.createSource(
            allocator,
            io,
            roots.cooked_root,
        );
        return init(allocator, io, source);
    }

    pub fn deinit(self: *AssetManager) void {
        self.deinitMaterialCache();
        self.deinitShaderProgramCache();
        self.deinitTextureCache();
        self.deinitMeshCache();
        self.source.deinit(self.allocator, self.io);
    }

    pub fn loadMesh(self: *AssetManager, path: []const u8) !*Mesh {
        const normalized_path = try self.normalizeExpected(path, .mesh);
        var key_owned = true;
        defer if (key_owned) self.allocator.free(normalized_path);

        if (self.meshes.get(normalized_path)) |cached| {
            return cached;
        }

        const bytes = try self.source.readAlloc(self.allocator, self.io, normalized_path);
        defer self.allocator.free(bytes);
        var reader = std.Io.Reader.fixed(bytes);

        const mesh = try self.allocator.create(Mesh);
        errdefer self.allocator.destroy(mesh);
        mesh.* = try loaders.loadMesh(self.allocator, &reader);
        errdefer mesh.deinit();

        try self.meshes.put(normalized_path, mesh);
        key_owned = false;
        return mesh;
    }

    pub fn loadMaterial(self: *AssetManager, path: []const u8) !*Material {
        const normalized_path = try self.normalizeExpected(path, .material);
        var key_owned = true;
        defer if (key_owned) self.allocator.free(normalized_path);

        if (self.materials.get(normalized_path)) |cached| {
            return cached;
        }

        const bytes = try self.source.readAlloc(self.allocator, self.io, normalized_path);
        defer self.allocator.free(bytes);
        var reader = std.Io.Reader.fixed(bytes);

        var material_source = try loaders.loadMaterialSource(self.allocator, &reader);
        var source_owned = true;
        errdefer if (source_owned) material_source.deinit(self.allocator);

        const vertex_path = try asset_path.resolveMaterialRelative(
            self.allocator,
            normalized_path,
            material_source.vertex_shader_path,
        );
        defer self.allocator.free(vertex_path);
        const fragment_path = try asset_path.resolveMaterialRelative(
            self.allocator,
            normalized_path,
            material_source.fragment_shader_path,
        );
        defer self.allocator.free(fragment_path);

        const shader = try self.loadShaderProgram(vertex_path, fragment_path);

        var texture_bindings: std.ArrayList(Material.TextureBinding) = .empty;
        errdefer texture_bindings.deinit(self.allocator);

        for (material_source.texture_slots) |slot| {
            if (slot.slot_index == std.math.maxInt(u16) or slot.cooked_path.len == 0) {
                continue;
            }

            const texture_path = try asset_path.resolveMaterialRelative(
                self.allocator,
                normalized_path,
                slot.cooked_path,
            );
            defer self.allocator.free(texture_path);

            const texture = try self.loadTexture(texture_path);
            try texture_bindings.append(self.allocator, .{
                .unit = slot.slot_index,
                .texture = texture,
                .slot_name_hash = slot.slot_name_hash,
            });
        }

        const texture_slice = try texture_bindings.toOwnedSlice(self.allocator);
        var texture_slice_owned = true;
        errdefer if (texture_slice_owned) self.allocator.free(texture_slice);

        const material = try self.allocator.create(Material);
        errdefer self.allocator.destroy(material);
        material.* = try Material.initFromSource(
            self.allocator,
            material_source,
            shader,
            texture_slice,
        );
        source_owned = false;
        texture_slice_owned = false;
        errdefer material.deinit();

        try self.materials.put(normalized_path, material);
        key_owned = false;
        return material;
    }

    pub fn loadTexture(self: *AssetManager, path: []const u8) !*Texture2D {
        const normalized_path = try self.normalizeExpected(path, .texture);
        var key_owned = true;
        defer if (key_owned) self.allocator.free(normalized_path);

        if (self.textures.get(normalized_path)) |cached| {
            return cached;
        }

        const bytes = try self.source.readAlloc(self.allocator, self.io, normalized_path);
        defer self.allocator.free(bytes);
        var reader = std.Io.Reader.fixed(bytes);

        const texture = try self.allocator.create(Texture2D);
        errdefer self.allocator.destroy(texture);
        texture.* = try loaders.loadTexture(self.allocator, &reader);
        errdefer texture.deinit();

        try self.textures.put(normalized_path, texture);
        key_owned = false;
        return texture;
    }

    pub fn loadShaderProgram(
        self: *AssetManager,
        vertex_path: []const u8,
        fragment_path: []const u8,
    ) !*Shader {
        const normalized_vertex = try self.normalizeExpected(vertex_path, .shader_stage);
        defer self.allocator.free(normalized_vertex);
        const normalized_fragment = try self.normalizeExpected(fragment_path, .shader_stage);
        defer self.allocator.free(normalized_fragment);

        const lookup_key = try makeShaderProgramKey(self.allocator, normalized_vertex, normalized_fragment);
        var key_owned = true;
        defer if (key_owned) self.allocator.free(lookup_key);

        if (self.shader_programs.get(lookup_key)) |cached| {
            return cached;
        }

        const vertex_bytes = try self.source.readAlloc(self.allocator, self.io, normalized_vertex);
        defer self.allocator.free(vertex_bytes);
        const fragment_bytes = try self.source.readAlloc(self.allocator, self.io, normalized_fragment);
        defer self.allocator.free(fragment_bytes);

        var vertex_reader = std.Io.Reader.fixed(vertex_bytes);
        var fragment_reader = std.Io.Reader.fixed(fragment_bytes);

        var vertex_stage = try loaders.loadShaderStage(self.allocator, &vertex_reader);
        defer vertex_stage.deinit(self.allocator);
        var fragment_stage = try loaders.loadShaderStage(self.allocator, &fragment_reader);
        defer fragment_stage.deinit(self.allocator);

        if (vertex_stage.stage != .vertex or fragment_stage.stage != .fragment) {
            return AssetError.WrongAssetKind;
        }

        const shader = try self.allocator.create(Shader);
        errdefer self.allocator.destroy(shader);
        shader.* = try loaders.linkShaderProgram(self.allocator, &vertex_stage, &fragment_stage);
        errdefer shader.deinit();

        try self.shader_programs.put(lookup_key, shader);
        key_owned = false;
        return shader;
    }

    fn normalizeExpected(self: *AssetManager, raw_path: []const u8, expected: AssetKind) ![]u8 {
        const normalized = asset_path.normalizeVirtualPath(self.allocator, raw_path) catch return AssetError.InvalidPath;
        errdefer self.allocator.free(normalized);
        const actual = asset_id.inferKind(normalized) orelse return AssetError.UnsupportedAssetKind;
        if (actual != expected) return AssetError.WrongAssetKind;
        return normalized;
    }

    fn deinitMaterialCache(self: *AssetManager) void {
        var it = self.materials.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.materials.deinit();
    }

    fn deinitShaderProgramCache(self: *AssetManager) void {
        var it = self.shader_programs.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.shader_programs.deinit();
    }

    fn deinitTextureCache(self: *AssetManager) void {
        var it = self.textures.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.textures.deinit();
    }

    fn deinitMeshCache(self: *AssetManager) void {
        var it = self.meshes.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.meshes.deinit();
    }
};

fn makeShaderProgramKey(
    allocator: std.mem.Allocator,
    vertex_path: []const u8,
    fragment_path: []const u8,
) ![]u8 {
    const key = try allocator.alloc(u8, vertex_path.len + 1 + fragment_path.len);
    @memcpy(key[0..vertex_path.len], vertex_path);
    key[vertex_path.len] = 0;
    @memcpy(key[vertex_path.len + 1 ..], fragment_path);
    return key;
}

test "makeShaderProgramKey includes both stage paths" {
    const key = try makeShaderProgramKey(std.testing.allocator, "basic.vert.zshdr", "basic.frag.zshdr");
    defer std.testing.allocator.free(key);
    try std.testing.expectEqualStrings("basic.vert.zshdr", key[0.."basic.vert.zshdr".len]);
    try std.testing.expectEqual(@as(u8, 0), key["basic.vert.zshdr".len]);
    try std.testing.expectEqualStrings("basic.frag.zshdr", key["basic.vert.zshdr".len + 1 ..]);
}
