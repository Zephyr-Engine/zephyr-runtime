const std = @import("std");
const zimp = @import("zimp");

const Mesh = @import("../graphics/mesh.zig").Mesh;
const Material = @import("../graphics/material.zig").Material;
const Shader = @import("../graphics/opengl/shader.zig").Shader;
const Texture2D = @import("../graphics/opengl/texture.zig").Texture2D;

pub fn loadMesh(
    allocator: std.mem.Allocator,
    reader: *std.Io.Reader,
) !Mesh {
    var mesh = try zimp.ZMesh.readFromReader(allocator, reader);
    defer mesh.deinit(allocator);
    return Mesh.loadFromZMesh(mesh);
}

pub fn loadTexture(
    allocator: std.mem.Allocator,
    reader: *std.Io.Reader,
) !Texture2D {
    var ztex = try zimp.Zatex.readFromReader(allocator, reader);
    defer ztex.deinit(allocator);
    return Texture2D.init(ztex);
}

pub fn loadShaderStage(
    allocator: std.mem.Allocator,
    reader: *std.Io.Reader,
) !zimp.ZShader {
    return zimp.ZShader.read(allocator, reader);
}

pub fn loadMaterialSource(
    allocator: std.mem.Allocator,
    reader: *std.Io.Reader,
) !zimp.Zamat {
    return zimp.Zamat.read(allocator, reader);
}

pub fn linkShaderProgram(
    allocator: std.mem.Allocator,
    vertex_stage: *const zimp.ZShader,
    fragment_stage: *const zimp.ZShader,
) !Shader {
    const vertex_source = try vertex_stage.baseSource();
    const fragment_source = try fragment_stage.baseSource();
    return Shader.init(allocator, vertex_source, fragment_source);
}

test {
    std.testing.refAllDecls(@This());
}
