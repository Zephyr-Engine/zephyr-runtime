const std = @import("std");
const zimp = @import("zimp");

const source_mod = @import("source.zig");

const AssetId = zimp.AssetId;
const AssetKind = zimp.AssetKind;
const AssetSource = source_mod.AssetSource;
const AssetError = source_mod.AssetError;
const FileSource = source_mod.FileSource;
const Mesh = @import("../graphics/mesh.zig").Mesh;
const Project = @import("../project/project.zig").Project;
const Material = @import("../graphics/material.zig").Material;
const Shader = @import("../graphics/opengl/shader.zig").Shader;
const Texture2D = @import("../graphics/opengl/texture.zig").Texture2D;

pub const AssetRef = struct {
    kind: AssetKind,
    id: AssetId,
};

pub const Asset = union(AssetKind) {
    mesh: *Mesh,
    texture: *Texture2D,
    shader_stage: void,
    material: *Material,

    fn deinit(self: Asset, allocator: std.mem.Allocator) void {
        switch (self) {
            .mesh => |mesh| {
                mesh.deinit();
                allocator.destroy(mesh);
            },
            .material => |material| {
                material.deinit();
                allocator.destroy(material);
            },
            .texture => |texture| {
                texture.deinit();
                allocator.destroy(texture);
            },
            .shader_stage => {},
        }
    }
};

const PathKey = struct {
    path: []u8,
};

pub const AssetManager = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    source: AssetSource,

    assets: std.AutoHashMap(AssetId, Asset),
    paths: std.StringHashMap(AssetId),
    path_keys: std.AutoHashMap(AssetId, PathKey),
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
            .assets = std.AutoHashMap(AssetId, Asset).init(allocator),
            .paths = std.StringHashMap(AssetId).init(allocator),
            .path_keys = std.AutoHashMap(AssetId, PathKey).init(allocator),
            .shader_programs = std.StringHashMap(*Shader).init(allocator),
        };
    }

    pub fn initFiles(
        allocator: std.mem.Allocator,
        io: std.Io,
        project: *const Project,
    ) !AssetManager {
        const cooked_dir = try std.Io.Dir.openDir(
            project.root_dir,
            io,
            project.manfiest.cookedAssetsPath(),
            .{},
        );
        errdefer cooked_dir.close(io);

        const source = try FileSource.createSource(
            allocator,
            project.manfiest.cookedAssetsPath(),
            cooked_dir,
        );
        return init(allocator, io, source);
    }

    pub fn deinit(self: *AssetManager) void {
        var assets_it = self.assets.valueIterator();
        while (assets_it.next()) |asset| {
            asset.*.deinit(self.allocator);
        }
        self.assets.deinit();

        var path_it = self.path_keys.valueIterator();
        while (path_it.next()) |key| {
            self.allocator.free(key.path);
        }
        self.path_keys.deinit();
        self.paths.deinit();

        var shader_it = self.shader_programs.iterator();
        while (shader_it.next()) |key| {
            key.value_ptr.*.deinit();
            self.allocator.destroy(key.value_ptr.*);
            self.allocator.free(key.key_ptr.*);
        }
        self.shader_programs.deinit();

        self.source.deinit(self.allocator, self.io);
    }

    pub fn register(self: *AssetManager, comptime T: type, path: []const u8) !AssetId {
        const expected = comptime kindFor(T);
        const normalized_path = try self.normalizeExpected(path, expected);
        if (self.paths.get(normalized_path)) |cached| {
            return cached;
        }

        const id = try self.newAssetId();
        const asset = try self.loadAsset(T, normalized_path);

        try self.assets.put(id, asset);
        errdefer _ = self.assets.remove(id);

        try self.path_keys.put(id, .{
            .path = normalized_path,
        });
        errdefer _ = self.path_keys.remove(id);

        try self.paths.put(normalized_path, id);

        return id;
    }

    pub fn get(self: *AssetManager, comptime T: type, id: AssetId) ?*T {
        const expected = comptime kindFor(T);
        const asset = self.assets.get(id) orelse return null;
        return switch (expected) {
            .mesh => switch (asset) {
                .mesh => |mesh| mesh,
                else => null,
            },
            .material => switch (asset) {
                .material => |material| material,
                else => null,
            },
            .texture => switch (asset) {
                .texture => |texture| texture,
                else => null,
            },
            .shader_stage => null,
        };
    }

    pub fn pathFor(self: *AssetManager, id: AssetId) ?[]const u8 {
        const key = self.path_keys.get(id) orelse return null;
        return key.path;
    }

    pub fn kindForId(self: *AssetManager, id: AssetId) ?AssetKind {
        const asset = self.assets.get(id) orelse return null;
        return std.meta.activeTag(asset);
    }

    pub fn loadMesh(self: *AssetManager, path: []const u8) !*Mesh {
        const id = try self.register(Mesh, path);
        return self.get(Mesh, id).?;
    }

    pub fn loadMaterial(self: *AssetManager, path: []const u8) !*Material {
        const id = try self.register(Material, path);
        return self.get(Material, id).?;
    }

    pub fn loadTexture(self: *AssetManager, path: []const u8) !*Texture2D {
        const id = try self.register(Texture2D, path);
        return self.get(Texture2D, id).?;
    }

    fn loadAsset(self: *AssetManager, comptime T: type, normalized_path: []const u8) !Asset {
        const kind = comptime kindFor(T);
        return switch (kind) {
            .mesh => .{ .mesh = try self.createMesh(normalized_path) },
            .material => .{ .material = try self.createMaterial(normalized_path) },
            .texture => .{ .texture = try self.createTexture(normalized_path) },
            .shader_stage => AssetError.WrongAssetKind,
        };
    }

    fn createMesh(self: *AssetManager, normalized_path: []const u8) !*Mesh {
        var cooked_asset = try self.loadCookedAsset(normalized_path, .mesh);
        defer cooked_asset.deinit(self.allocator);
        const cooked_mesh = switch (cooked_asset) {
            .mesh => |mesh| mesh,
            else => unreachable,
        };

        const mesh = try self.allocator.create(Mesh);
        errdefer self.allocator.destroy(mesh);
        mesh.* = try Mesh.loadFromZmesh(self.allocator, cooked_mesh);
        errdefer mesh.deinit();

        return mesh;
    }

    fn createMaterial(self: *AssetManager, normalized_path: []const u8) !*Material {
        const cooked_asset = try self.loadCookedAsset(normalized_path, .material);
        var material_source = switch (cooked_asset) {
            .material => |source| source,
            else => unreachable,
        };
        var source_owned = true;
        errdefer if (source_owned) material_source.deinit(self.allocator);

        const vertex_path = try self.normalizeExpected(
            material_source.vertex_shader_path,
            .shader_stage,
        );
        defer self.allocator.free(vertex_path);
        const fragment_path = try self.normalizeExpected(
            material_source.fragment_shader_path,
            .shader_stage,
        );
        defer self.allocator.free(fragment_path);

        const shader = try self.loadShaderProgram(vertex_path, fragment_path);

        var texture_bindings: std.ArrayList(Material.TextureBinding) = .empty;
        errdefer texture_bindings.deinit(self.allocator);

        for (material_source.texture_slots) |slot| {
            if (slot.slot_index == std.math.maxInt(u16) or slot.cooked_path.len == 0) {
                continue;
            }

            const texture_path = try self.normalizeExpected(
                slot.cooked_path,
                .texture,
            );
            defer self.allocator.free(texture_path);

            const texture_id = try self.register(Texture2D, texture_path);
            const texture = self.get(Texture2D, texture_id).?;
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

        return material;
    }

    fn createTexture(self: *AssetManager, normalized_path: []const u8) !*Texture2D {
        var cooked_asset = try self.loadCookedAsset(normalized_path, .texture);
        defer cooked_asset.deinit(self.allocator);
        const cooked_texture = switch (cooked_asset) {
            .texture => |texture| texture,
            else => unreachable,
        };

        const texture = try self.allocator.create(Texture2D);
        errdefer self.allocator.destroy(texture);
        texture.* = try Texture2D.init(cooked_texture);
        errdefer texture.deinit();

        return texture;
    }

    fn loadShaderProgram(
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

        if (self.shader_programs.get(lookup_key)) |shader| {
            return shader;
        }

        var vertex_asset = try self.loadCookedAsset(normalized_vertex, .shader_stage);
        defer vertex_asset.deinit(self.allocator);
        var fragment_asset = try self.loadCookedAsset(normalized_fragment, .shader_stage);
        defer fragment_asset.deinit(self.allocator);

        const vertex_stage = switch (vertex_asset) {
            .shader => |*shader| shader,
            else => unreachable,
        };
        const fragment_stage = switch (fragment_asset) {
            .shader => |*shader| shader,
            else => unreachable,
        };

        if (vertex_stage.stage != .vertex or fragment_stage.stage != .fragment) {
            return AssetError.WrongAssetKind;
        }

        const shader = try self.allocator.create(Shader);
        errdefer self.allocator.destroy(shader);
        shader.* = try linkShaderProgram(self.allocator, vertex_stage, fragment_stage);
        errdefer shader.deinit();

        try self.shader_programs.put(lookup_key, shader);
        key_owned = false;

        return shader;
    }

    fn loadCookedAsset(
        self: *AssetManager,
        normalized_path: []const u8,
        expected: AssetKind,
    ) !zimp.runtime.Asset {
        const bytes = try self.source.readAlloc(self.allocator, self.io, normalized_path);
        defer self.allocator.free(bytes);

        var reader = std.Io.Reader.fixed(bytes);
        return zimp.runtime.loadFromReader(self.allocator, &reader, expected.toAssetType());
    }

    fn normalizeExpected(self: *AssetManager, raw_path: []const u8, expected: AssetKind) ![]u8 {
        const normalized = zimp.path.normalizeVirtual(self.allocator, raw_path) catch return AssetError.InvalidPath;
        errdefer self.allocator.free(normalized);
        const actual = inferKind(normalized) orelse return AssetError.UnsupportedAssetKind;
        if (actual != expected) return AssetError.WrongAssetKind;
        return normalized;
    }

    fn newAssetId(self: *AssetManager) !AssetId {
        while (true) {
            const random_source: std.Random.IoSource = .{ .io = self.io };
            const id = AssetId.v4(random_source.interface());
            if (id.isZero()) continue;
            if (!self.assets.contains(id)) return id;
        }
    }
};

fn inferKind(path: []const u8) ?AssetKind {
    const asset_type = zimp.runtime.detectType(path) orelse return null;
    return AssetKind.fromAssetType(asset_type);
}

fn linkShaderProgram(
    allocator: std.mem.Allocator,
    vertex_stage: *const zimp.ZShader,
    fragment_stage: *const zimp.ZShader,
) !Shader {
    const vertex_source = try vertex_stage.baseSource();
    const fragment_source = try fragment_stage.baseSource();
    return Shader.init(allocator, vertex_source, fragment_source);
}

fn kindFor(comptime T: type) AssetKind {
    return switch (T) {
        Mesh => .mesh,
        Material => .material,
        Texture2D => .texture,
        Shader => .shader_program,
        else => @compileError("unsupported asset type: " ++ @typeName(T)),
    };
}

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
