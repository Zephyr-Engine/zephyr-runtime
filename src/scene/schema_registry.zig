const std = @import("std");
const zimp = @import("zimp");
const codec_mod = @import("component_codec.zig");

const ComponentTypeId = zimp.id.types.ComponentTypeId;
const deriveCodec = @import("derive_schema.zig").deriveCodec;

pub fn SchemaRegistry(comptime Ecs: type) type {
    const Codec = codec_mod.ComponentCodec(Ecs);

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        codecs: std.AutoHashMap(ComponentTypeId, Codec),
        names: std.StringHashMap(ComponentTypeId),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .codecs = std.AutoHashMap(ComponentTypeId, Codec).init(allocator),
                .names = std.StringHashMap(ComponentTypeId).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.codecs.deinit();
            self.names.deinit();
        }

        pub fn register(self: *Self, comptime Component: type) !void {
            const codec = comptime deriveCodec(Ecs, Component);
            try zimp.scene.validateSchema(codec.schema);

            if (self.codecs.contains(codec.schema.id)) {
                return error.DuplicateComponentId;
            }

            if (self.names.contains(codec.schema.name)) {
                return error.DuplicateComponentName;
            }

            try self.codecs.put(codec.schema.id, codec);
            try self.names.put(codec.schema.name, codec.schema.id);
        }

        pub fn get(self: *const Self, id: ComponentTypeId) ?*const Codec {
            return self.codecs.getPtr(id);
        }

        pub fn getByName(self: *const Self, name: []const u8) ?*const Codec {
            const id = self.names.get(name) orelse return null;
            return self.get(id);
        }

        pub fn sortedSchemas(self: *const Self, allocator: std.mem.Allocator) ![]zimp.scene.ComponentSchema {
            var out = try allocator.alloc(zimp.scene.ComponentSchema, self.codecs.count());
            var it = self.codecs.valueIterator();
            var i: usize = 0;
            while (it.next()) |codec| : (i += 1) out[i] = codec.schema;
            std.mem.sort(zimp.scene.ComponentSchema, out, {}, struct {
                fn lessThan(_: void, a: zimp.scene.ComponentSchema, b: zimp.scene.ComponentSchema) bool {
                    return std.mem.order(u8, &a.id.uuid.bytes, &b.id.uuid.bytes) == .lt;
                }
            }.lessThan);
            return out;
        }

        pub fn schemaHash(self: *const Self, allocator: std.mem.Allocator) !u64 {
            const schemas = try self.sortedSchemas(allocator);
            defer allocator.free(schemas);
            return zimp.scene.schemaHash(schemas);
        }

        pub fn descriptor(self: *const Self, allocator: std.mem.Allocator) !zimp.scene.SchemaDescriptor {
            const schemas = try self.sortedSchemas(allocator);
            return .{
                .schema_hash = zimp.scene.schemaHash(schemas),
                .components = schemas,
            };
        }
    };
}
