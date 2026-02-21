const std = @import("std");
const Texture = @import("../graphics/opengl_texture.zig").Texture;
const Material = @import("material.zig").Material;
const MaterialInstance = @import("material.zig").MaterialInstance;
const Model = @import("model.zig").Model;
const VertexArray = @import("../graphics/opengl_vertex_array.zig").VertexArray;
const Transform = @import("transform.zig").Transform;
const AssetManager = @import("manager.zig").AssetManager;
const AssetHandle = @import("manager.zig").AssetHandle;
const gltf = @import("gltf.zig");

pub const GltfPbrDesc = struct {
    gltf_json: []const u8,
    bin_data: []const u8,
    base_color: []const u8,
    metallic_roughness: []const u8,
    normal: []const u8,
    transform: Transform = Transform.default,
};

pub const AssetLoader = struct {
    pub fn loadGltfPbr(allocator: std.mem.Allocator, desc: GltfPbrDesc) !AssetHandle {
        const shader = try AssetManager.getOrCreateBuiltinPbrShader(allocator);

        const base_color_tex = blk: {
            var tex = try Texture.fromData(desc.base_color, 4);
            tex.generateMipmaps();
            tex.setWrapRepeat();
            break :blk try AssetManager.PushTexture(allocator, tex);
        };

        const metal_rough_tex = blk: {
            var tex = try Texture.fromData(desc.metallic_roughness, 4);
            tex.generateMipmaps();
            tex.setWrapRepeat();
            break :blk try AssetManager.PushTexture(allocator, tex);
        };

        const normal_tex = blk: {
            var tex = try Texture.fromData(desc.normal, 4);
            tex.generateMipmaps();
            tex.setWrapRepeat();
            break :blk try AssetManager.PushTexture(allocator, tex);
        };

        const mat = try AssetManager.PushMaterial(allocator, Material.init(allocator, shader));

        var inst = mat.instaniate(.{
            .ambient = .{ .x = 0.2, .y = 0.2, .z = 0.2 },
            .diffuse = .{ .x = 0.8, .y = 0.8, .z = 0.8 },
            .specular = .{ .x = 0.5, .y = 0.5, .z = 0.5 },
            .shininess = 64.0,
        });
        inst.base_color_texture = base_color_tex;
        inst.metallic_roughness_texture = metal_rough_tex;
        inst.normal_texture = normal_tex;

        const mat_inst = try AssetManager.PushMaterialInstance(allocator, inst);

        var result = try gltf.parse(allocator, desc.gltf_json, desc.bin_data);
        const vao = try VertexArray.init(result.mesh.vertices, result.mesh.indices);
        result.mesh.deinit();

        try vao.setLayout(shader.buffer_layout);

        const model = Model{
            .vao = vao,
            .material = mat_inst,
            .transform = desc.transform,
        };

        return try AssetManager.PushModel(allocator, model);
    }
};
