const std = @import("std");
const Model = @import("model.zig").Model;
const ModelList = std.ArrayList(Model);

pub const AssetHandle = usize;

pub const AssetManager = struct {
    models: ModelList,

    var instance: ?AssetManager = null;
    var once = std.once(init);

    fn init() void {
        instance = AssetManager{
            .models = .empty,
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

    pub fn Deinit(allocator: std.mem.Allocator) void {
        const self = getInstance();
        self.models.deinit(allocator);
    }
};
