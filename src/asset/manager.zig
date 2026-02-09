const std = @import("std");
const math = @import("zlm").as(f32);
const Model = @import("model.zig").Model;
const Light = @import("light.zig").Light;
const ModelList = std.ArrayList(Model);
const LightList = std.ArrayList(Light);

pub const AssetHandle = usize;

pub const LightHandle = usize;

pub const AssetManager = struct {
    models: ModelList,
    lights: LightList,

    var instance: ?AssetManager = null;
    var once = std.once(init);

    fn init() void {
        instance = AssetManager{
            .models = .empty,
            .lights = .empty,
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
    }
};
