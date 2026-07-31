const std = @import("std");
const zcs = @import("zcs");

const SchemaRegistry = @import("../scene/schema_registry.zig").SchemaRegistry;
const AssetManager = @import("../assets/asset_manager.zig").AssetManager;
const Project = @import("../project/project.zig").Project;

pub const RuntimeContext = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    assets: *AssetManager,
    project: *const Project,
    schemas: *const SchemaRegistry,
    world: zcs.World,
};
