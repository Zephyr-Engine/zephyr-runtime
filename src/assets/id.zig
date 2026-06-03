const std = @import("std");

pub const AssetKind = enum(u8) {
    mesh,
    material,
    texture,
    shader_stage,
    shader_program,
};

pub const AssetId = struct {
    kind: AssetKind,
    path_hash: u64,
};

pub const AssetRef = struct {
    kind: AssetKind,
    path: []const u8,
};

pub const ShaderProgramId = struct {
    vertex_path_hash: u64,
    fragment_path_hash: u64,
    combined_hash: u64,
};

pub fn idFromNormalizedPath(kind: AssetKind, normalized_path: []const u8) AssetId {
    return .{
        .kind = kind,
        .path_hash = fnv1a(normalized_path),
    };
}

pub fn shaderProgramId(vertex_path: []const u8, fragment_path: []const u8) ShaderProgramId {
    return .{
        .vertex_path_hash = fnv1a(vertex_path),
        .fragment_path_hash = fnv1a(fragment_path),
        .combined_hash = fnv1aPair(vertex_path, fragment_path),
    };
}

pub fn inferKind(path: []const u8) ?AssetKind {
    const dot_index = std.mem.lastIndexOfScalar(u8, path, '.') orelse return null;
    const ext = path[dot_index..];
    if (std.mem.eql(u8, ext, ".zmesh")) {
        return .mesh;
    }
    if (std.mem.eql(u8, ext, ".zamat")) {
        return .material;
    }
    if (std.mem.eql(u8, ext, ".ztex")) {
        return .texture;
    }
    if (std.mem.eql(u8, ext, ".zshdr")) {
        return .shader_stage;
    }
    return null;
}

pub fn fnv1a(bytes: []const u8) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    for (bytes) |byte| {
        hash ^= byte;
        hash *%= 0x00000100000001B3;
    }
    return hash;
}

fn fnv1aPair(first: []const u8, second: []const u8) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    for (first) |byte| {
        hash ^= byte;
        hash *%= 0x00000100000001B3;
    }
    hash ^= 0;
    hash *%= 0x00000100000001B3;
    for (second) |byte| {
        hash ^= byte;
        hash *%= 0x00000100000001B3;
    }
    return hash;
}

const testing = std.testing;

test "inferKind maps supported cooked extensions" {
    try testing.expectEqual(AssetKind.mesh, inferKind("monkey.zmesh").?);
    try testing.expectEqual(AssetKind.material, inferKind("monkey.zamat").?);
    try testing.expectEqual(AssetKind.texture, inferKind("brick_albedo.ztex").?);
    try testing.expectEqual(AssetKind.shader_stage, inferKind("basic.vert.zshdr").?);
}

test "inferKind requires lowercase cooked extensions" {
    try testing.expect(inferKind("MONKEY.ZMESH") == null);
}

test "idFromNormalizedPath uses fnv1a path hash" {
    const id = idFromNormalizedPath(.mesh, "meshes/monkey.zmesh");
    try testing.expectEqual(AssetKind.mesh, id.kind);
    try testing.expectEqual(fnv1a("meshes/monkey.zmesh"), id.path_hash);
}
