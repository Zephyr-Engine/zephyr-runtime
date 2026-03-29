const std = @import("std");
const math = @import("zlm").as(f32);
const Model = @import("model.zig").Model;
const Light = @import("light.zig").Light;
const Texture = @import("../graphics/opengl_texture.zig").Texture;
const Material = @import("material.zig").Material;
const MaterialInstance = @import("material.zig").MaterialInstance;
const Lighting = @import("material.zig").Lighting;
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const VertexArray = @import("../graphics/opengl_vertex_array.zig").VertexArray;
const Transform = @import("transform.zig").Transform;
const gltf = @import("gltf.zig");
const Camera = @import("../scene/camera.zig").Camera;
const ModelList = std.ArrayList(Model);
const LightList = std.ArrayList(Light);
const CameraList = std.ArrayList(Camera);

pub const AssetHandle = usize;

pub const LightHandle = usize;

pub const CameraHandle = usize;

pub const GltfPbrDesc = struct {
    gltf_json: []const u8,
    bin_data: []const u8,
    base_color: []const u8,
    metallic_roughness: []const u8,
    normal: []const u8,
    transform: Transform = Transform.default,
};

pub const ObjDesc = struct {
    obj: []const u8,
    instance: *const MaterialInstance,
    transform: Transform = Transform.default,
};

pub const AssetManager = struct {
    models: ModelList,
    lights: LightList,
    cameras: CameraList,
    shaders: std.ArrayList(*Shader),
    textures: std.ArrayList(*Texture),
    materials: std.ArrayList(*Material),
    material_instances: std.ArrayList(*MaterialInstance),
    builtin_pbr_shader: ?*Shader = null,

    var instance: ?AssetManager = null;

    inline fn getInstance() *AssetManager {
        if (instance == null) {
            instance = AssetManager{
                .models = .empty,
                .lights = .empty,
                .cameras = .empty,
                .shaders = .empty,
                .textures = .empty,
                .materials = .empty,
                .material_instances = .empty,
            };
        }
        return &instance.?;
    }

    fn pushModel(allocator: std.mem.Allocator, model: Model) !AssetHandle {
        const self = getInstance();
        const handle = self.models.items.len;
        try self.models.append(allocator, model);
        return handle;
    }

    pub fn GetModel(handle: AssetHandle) *Model {
        const self = getInstance();
        return &self.models.items[handle];
    }

    pub fn GetModels() []Model {
        const self = getInstance();
        return self.models.items;
    }

    pub fn GetWorldMatrix(handle: AssetHandle) math.Mat4 {
        const self = getInstance();
        const model = &self.models.items[handle];
        const local = model.transform.localMatrix();

        if (model.transform.parent) |parent_handle| {
            const parent_world = GetWorldMatrix(parent_handle);
            return parent_world.mul(local);
        }

        return local;
    }

    pub fn SetParent(allocator: std.mem.Allocator, child: AssetHandle, parent: AssetHandle) !void {
        const self = getInstance();
        var child_model = &self.models.items[child];

        if (child_model.transform.parent) |old_parent| {
            var old_parent_model = &self.models.items[old_parent];
            removeChildFromList(&old_parent_model.transform.children, child);
        }

        child_model.transform.parent = parent;
        var parent_model = &self.models.items[parent];
        try parent_model.transform.children.append(allocator, child);
    }

    pub fn RemoveParent(child: AssetHandle) void {
        const self = getInstance();
        var child_model = &self.models.items[child];

        if (child_model.transform.parent) |parent_handle| {
            var parent_model = &self.models.items[parent_handle];
            removeChildFromList(&parent_model.transform.children, child);
            child_model.transform.parent = null;
        }
    }

    fn removeChildFromList(children: *std.ArrayListUnmanaged(AssetHandle), child: AssetHandle) void {
        for (children.items, 0..) |item, i| {
            if (item == child) {
                _ = children.swapRemove(i);
                return;
            }
        }
    }

    fn pushShader(allocator: std.mem.Allocator, shader: Shader) !*Shader {
        const self = getInstance();
        const ptr = try allocator.create(Shader);
        ptr.* = shader;
        try self.shaders.append(allocator, ptr);
        return ptr;
    }

    fn pushTexture(allocator: std.mem.Allocator, tex: Texture) !*Texture {
        const self = getInstance();
        const ptr = try allocator.create(Texture);
        ptr.* = tex;
        try self.textures.append(allocator, ptr);
        return ptr;
    }

    fn pushMaterial(allocator: std.mem.Allocator, mat: Material) !*Material {
        const self = getInstance();
        const ptr = try allocator.create(Material);
        ptr.* = mat;
        try self.materials.append(allocator, ptr);
        return ptr;
    }

    fn pushMaterialInstance(allocator: std.mem.Allocator, inst: MaterialInstance) !*MaterialInstance {
        const self = getInstance();
        const ptr = try allocator.create(MaterialInstance);
        ptr.* = inst;
        try self.material_instances.append(allocator, ptr);
        return ptr;
    }

    pub fn LoadShader(allocator: std.mem.Allocator, vs_src: []const u8, fs_src: []const u8) !*Shader {
        const shader = try Shader.init(allocator, vs_src, fs_src);
        return try pushShader(allocator, shader);
    }

    pub fn LoadTexture(allocator: std.mem.Allocator, image_data: []const u8, channels: c_int) !*Texture {
        var tex = try Texture.fromData(image_data, channels);
        tex.generateMipmaps();
        tex.setWrapRepeat();
        return try pushTexture(allocator, tex);
    }

    pub fn LoadMaterial(allocator: std.mem.Allocator, shader: *Shader) !*Material {
        return try pushMaterial(allocator, Material.init(allocator, shader));
    }

    pub fn LoadMaterialInstance(allocator: std.mem.Allocator, mat: *Material, lighting: Lighting) !*MaterialInstance {
        return try pushMaterialInstance(allocator, mat.instaniate(lighting));
    }

    pub fn LoadModel(allocator: std.mem.Allocator, desc: ObjDesc) !AssetHandle {
        const model = try Model.init(allocator, desc.obj, desc.instance, desc.transform);
        return try pushModel(allocator, model);
    }

    pub fn LoadGltfPbr(allocator: std.mem.Allocator, desc: GltfPbrDesc) !AssetHandle {
        const shader = try getOrCreateBuiltinPbrShader(allocator);

        const base_color_tex = try LoadTexture(allocator, desc.base_color, 4);
        const metal_rough_tex = try LoadTexture(allocator, desc.metallic_roughness, 4);
        const normal_tex = try LoadTexture(allocator, desc.normal, 4);

        const mat = try pushMaterial(allocator, Material.init(allocator, shader));

        var inst = mat.instaniate(.{
            .ambient = .{ .x = 0.2, .y = 0.2, .z = 0.2 },
            .diffuse = .{ .x = 0.8, .y = 0.8, .z = 0.8 },
            .specular = .{ .x = 0.5, .y = 0.5, .z = 0.5 },
            .shininess = 64.0,
        });
        inst.base_color_texture = base_color_tex;
        inst.metallic_roughness_texture = metal_rough_tex;
        inst.normal_texture = normal_tex;

        const mat_inst = try pushMaterialInstance(allocator, inst);

        var result = try gltf.parse(allocator, desc.gltf_json, desc.bin_data);
        const vao = try VertexArray.init(result.mesh.vertices, result.mesh.indices);
        result.mesh.deinit();

        try vao.setLayout(shader.buffer_layout);

        const model = Model{
            .vao = vao,
            .material = mat_inst,
            .transform = desc.transform,
        };

        return try pushModel(allocator, model);
    }

    pub fn getOrCreateBuiltinPbrShader(allocator: std.mem.Allocator) !*Shader {
        const self = getInstance();
        if (self.builtin_pbr_shader) |shader| return shader;

        const pbr_vs = @embedFile("../graphics/shaders/pbr_vertex.glsl");
        const pbr_fs = @embedFile("../graphics/shaders/pbr_fragment.glsl");

        const shader = try allocator.create(Shader);
        shader.* = try Shader.init(allocator, pbr_vs, pbr_fs);
        self.builtin_pbr_shader = shader;
        return shader;
    }

    pub fn PushLight(allocator: std.mem.Allocator, light: Light) !LightHandle {
        const self = getInstance();
        const handle = self.lights.items.len;
        try self.lights.append(allocator, light);
        return handle;
    }

    pub fn GetLight(handle: LightHandle) *Light {
        const self = getInstance();
        return &self.lights.items[handle];
    }

    pub fn GetLights() []Light {
        const self = getInstance();
        return self.lights.items;
    }

    pub fn LightCount() usize {
        const self = getInstance();
        return self.lights.items.len;
    }

    pub fn PushCamera(allocator: std.mem.Allocator, camera: Camera) !CameraHandle {
        const self = getInstance();
        const handle = self.cameras.items.len;
        try self.cameras.append(allocator, camera);
        return handle;
    }

    pub fn GetCamera(handle: CameraHandle) *Camera {
        const self = getInstance();
        return &self.cameras.items[handle];
    }

    pub fn GetActiveCamera() ?*Camera {
        const self = getInstance();
        for (self.cameras.items) |*camera| {
            if (camera.is_active) return camera;
        }
        return null;
    }

    pub fn GetActiveCameraHandle() ?CameraHandle {
        const self = getInstance();
        for (self.cameras.items, 0..) |camera, i| {
            if (camera.is_active) return i;
        }
        return null;
    }

    pub fn Deinit(allocator: std.mem.Allocator) void {
        const self = getInstance();
        for (self.models.items) |*model| {
            model.deinit(allocator);
        }
        self.models.deinit(allocator);
        self.lights.deinit(allocator);
        self.cameras.deinit(allocator);

        for (self.textures.items) |tex| {
            var t = tex.*;
            t.deinit();
            allocator.destroy(tex);
        }
        self.textures.deinit(allocator);

        for (self.material_instances.items) |inst| {
            allocator.destroy(inst);
        }
        self.material_instances.deinit(allocator);

        for (self.materials.items) |mat| {
            allocator.destroy(mat);
        }
        self.materials.deinit(allocator);

        for (self.shaders.items) |shader| {
            var s = shader.*;
            s.deinit();
            allocator.destroy(shader);
        }
        self.shaders.deinit(allocator);

        if (self.builtin_pbr_shader) |shader| {
            var s = shader.*;
            s.deinit();
            allocator.destroy(shader);
        }
    }
};
