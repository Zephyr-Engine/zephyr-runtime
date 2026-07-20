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
        pub fn registerMany(self: *Self, comptime Components: []const type) !void {
            inline for (Components) |Component| {
                try self.register(Component);
            }
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
            return zimp.scene.descriptor.schemaHash(schemas);
        }

        pub fn descriptor(self: *const Self, allocator: std.mem.Allocator) !zimp.scene.descriptor.SchemaDescriptor {
            const schemas = try self.sortedSchemas(allocator);
            return .{
                .schema_hash = zimp.scene.descriptor.schemaHash(schemas),
                .components = schemas,
            };
        }
    };
}

const testing = std.testing;

const RegistryComponentA = struct {
    enabled: bool = true,

    pub const schema_meta: zimp.scene.SchemaMeta = .{
        .id = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
        .name = "RegistryComponentA",
        .display_name = "Registry Component A",
        .version = 1,
        .fields = &.{.{
            .name = "enabled",
            .number = 1,
        }},
    };
};

const RegistryComponentB = struct {
    count: i32 = -2,

    pub const schema_meta: zimp.scene.SchemaMeta = .{
        .id = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        .name = "RegistryComponentB",
        .version = 3,
        .fields = &.{.{
            .name = "count",
            .number = 1,
        }},
    };
};

const DuplicateIdComponent = struct {
    visible: bool = false,

    pub const schema_meta: zimp.scene.SchemaMeta = .{
        .id = RegistryComponentA.schema_meta.id,
        .name = "DuplicateIdComponent",
        .version = 1,
        .fields = &.{.{
            .name = "visible",
            .number = 1,
        }},
    };
};

const DuplicateNameComponent = struct {
    active: bool = false,

    pub const schema_meta: zimp.scene.SchemaMeta = .{
        .id = "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
        .name = RegistryComponentA.schema_meta.name,
        .version = 1,
        .fields = &.{.{
            .name = "active",
            .number = 1,
        }},
    };
};

const InvalidSchemaComponent = struct {
    bad: bool = false,

    pub const schema_meta: zimp.scene.SchemaMeta = .{
        .id = "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
        .name = "",
        .version = 1,
        .fields = &.{.{
            .name = "bad",
            .number = 1,
        }},
    };
};

const TestEcs = @import("../ecs/world.zig").GameEcs(&.{
    RegistryComponentA,
    RegistryComponentB,
    DuplicateIdComponent,
    DuplicateNameComponent,
    InvalidSchemaComponent,
});

test "SchemaRegistry registers derived codecs and looks them up by id and name" {
    const Registry = SchemaRegistry(TestEcs);
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();

    try registry.register(RegistryComponentA);

    const expected_id = ComponentTypeId.parseComptime(RegistryComponentA.schema_meta.id);
    const by_id = registry.get(expected_id).?;
    try testing.expect(by_id.schema.id.eql(expected_id));
    try testing.expectEqualStrings("RegistryComponentA", by_id.schema.name);
    try testing.expectEqualStrings("Registry Component A", by_id.schema.display_name);

    const by_name = registry.getByName("RegistryComponentA").?;
    try testing.expect(by_name.schema.id.eql(expected_id));
    try testing.expect(registry.get(ComponentTypeId.zero) == null);
    try testing.expect(registry.getByName("MissingComponent") == null);
}

test "SchemaRegistry rejects duplicate component ids and names" {
    const Registry = SchemaRegistry(TestEcs);
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();

    try registry.register(RegistryComponentA);
    try testing.expectError(error.DuplicateComponentId, registry.register(DuplicateIdComponent));
    try testing.expectError(error.DuplicateComponentName, registry.register(DuplicateNameComponent));
}

test "SchemaRegistry returns schemas sorted by component id" {
    const Registry = SchemaRegistry(TestEcs);
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();

    try registry.register(RegistryComponentA);
    try registry.register(RegistryComponentB);

    const schemas = try registry.sortedSchemas(testing.allocator);
    defer testing.allocator.free(schemas);

    try testing.expectEqual(@as(usize, 2), schemas.len);
    try testing.expect(schemas[0].id.eql(ComponentTypeId.parseComptime(RegistryComponentB.schema_meta.id)));
    try testing.expect(schemas[1].id.eql(ComponentTypeId.parseComptime(RegistryComponentA.schema_meta.id)));
}

test "SchemaRegistry computes descriptor and schema hash from sorted schemas" {
    const Registry = SchemaRegistry(TestEcs);
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();

    try registry.register(RegistryComponentA);
    try registry.register(RegistryComponentB);

    const hash = try registry.schemaHash(testing.allocator);
    var descriptor = try registry.descriptor(testing.allocator);
    defer testing.allocator.free(descriptor.components);

    try testing.expectEqual(hash, descriptor.schema_hash);
    try testing.expectEqual(@as(usize, 2), descriptor.components.len);
    try testing.expect(descriptor.components[0].id.eql(ComponentTypeId.parseComptime(RegistryComponentB.schema_meta.id)));
    try testing.expect(descriptor.components[1].id.eql(ComponentTypeId.parseComptime(RegistryComponentA.schema_meta.id)));
}

test "SchemaRegistry validates derived schemas before insertion" {
    const Registry = SchemaRegistry(TestEcs);
    var registry = Registry.init(testing.allocator);
    defer registry.deinit();

    try testing.expectError(error.InvalidComponentName, registry.register(InvalidSchemaComponent));
    try testing.expectEqual(@as(usize, 0), registry.codecs.count());
    try testing.expectEqual(@as(usize, 0), registry.names.count());
}
