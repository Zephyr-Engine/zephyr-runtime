const std = @import("std");
const math = @import("zlm").as(f32);
const Quat = @import("math.zig").Quat;
const AssetManager = @import("../asset/manager.zig").AssetManager;

const TransformData = struct {
    position: math.Vec3,
    rotation: Quat,
    scale: math.Vec3,
};

pub const SceneSnapshot = struct {
    transforms: std.ArrayList(TransformData),

    pub fn init() SceneSnapshot {
        return .{
            .transforms = .empty,
        };
    }

    pub fn deinit(self: *SceneSnapshot, allocator: std.mem.Allocator) void {
        self.transforms.deinit(allocator);
    }

    pub fn save(self: *SceneSnapshot, allocator: std.mem.Allocator) void {
        const models = AssetManager.GetModels();
        self.transforms.clearRetainingCapacity();
        self.transforms.ensureTotalCapacity(allocator, models.len) catch return;
        for (models) |model| {
            self.transforms.appendAssumeCapacity(.{
                .position = model.transform.position,
                .rotation = model.transform.rotation,
                .scale = model.transform.scale,
            });
        }
    }

    pub fn restore(self: *const SceneSnapshot) void {
        const models = AssetManager.GetModels();
        for (models, 0..) |*model, i| {
            if (i >= self.transforms.items.len) break;
            const saved = self.transforms.items[i];
            model.transform.position = saved.position;
            model.transform.rotation = saved.rotation;
            model.transform.scale = saved.scale;
        }
    }
};
