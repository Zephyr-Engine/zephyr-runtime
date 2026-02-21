const std = @import("std");
const math = @import("zlm").as(f32);
const Model = @import("model.zig").Model;
const Light = @import("light.zig").Light;
const Texture = @import("../graphics/opengl_texture.zig").Texture;
const Material = @import("material.zig").Material;
const MaterialInstance = @import("material.zig").MaterialInstance;
const Shader = @import("../graphics/opengl_shader.zig").Shader;
const ModelList = std.ArrayList(Model);
const LightList = std.ArrayList(Light);

pub const AssetHandle = usize;

pub const LightHandle = usize;

pub const AssetManager = struct {
    models: ModelList,
    lights: LightList,
    shaders: std.ArrayList(*Shader),
    textures: std.ArrayList(*Texture),
    materials: std.ArrayList(*Material),
    material_instances: std.ArrayList(*MaterialInstance),
    builtin_pbr_shader: ?*Shader = null,

    var instance: ?AssetManager = null;
    var once = std.once(init);

    fn init() void {
        instance = AssetManager{
            .models = .empty,
            .lights = .empty,
            .shaders = .empty,
            .textures = .empty,
            .materials = .empty,
            .material_instances = .empty,
        };
    }

    inline fn getInstance() *AssetManager {
        once.call();
        return &instance.?;
    }

    pub fn PushModel(allocator: std.mem.Allocator, model: Model) !AssetHandle {
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

    pub fn PushShader(allocator: std.mem.Allocator, shader: Shader) !*Shader {
        const self = getInstance();
        const ptr = try allocator.create(Shader);
        ptr.* = shader;
        try self.shaders.append(allocator, ptr);
        return ptr;
    }

    pub fn PushTexture(allocator: std.mem.Allocator, tex: Texture) !*Texture {
        const self = getInstance();
        const ptr = try allocator.create(Texture);
        ptr.* = tex;
        try self.textures.append(allocator, ptr);
        return ptr;
    }

    pub fn PushMaterial(allocator: std.mem.Allocator, mat: Material) !*Material {
        const self = getInstance();
        const ptr = try allocator.create(Material);
        ptr.* = mat;
        try self.materials.append(allocator, ptr);
        return ptr;
    }

    pub fn PushMaterialInstance(allocator: std.mem.Allocator, inst: MaterialInstance) !*MaterialInstance {
        const self = getInstance();
        const ptr = try allocator.create(MaterialInstance);
        ptr.* = inst;
        try self.material_instances.append(allocator, ptr);
        return ptr;
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

    pub fn Deinit(allocator: std.mem.Allocator) void {
        const self = getInstance();
        for (self.models.items) |*model| {
            model.deinit(allocator);
        }
        self.models.deinit(allocator);
        self.lights.deinit(allocator);

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
