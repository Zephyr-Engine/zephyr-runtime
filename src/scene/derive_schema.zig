const zimp = @import("zimp");
const zcs = @import("zcs");
const std = @import("std");

const math = @import("../core/math.zig");
const codec = @import("component_codec.zig");

const id_types = zimp.id.types;

const ComponentCodec = codec.ComponentCodec;
const FieldKind = zimp.scene.FieldKind;
const Value = zimp.scene.Value;

fn autoFieldKind(comptime FT: type) ?FieldKind {
    return switch (FT) {
        i32 => .i32,
        u32 => .u32,
        f32 => .f32,
        bool => .bool,
        math.Vec2 => .vec2,
        math.Vec3 => .vec3,
        math.Quat => .quat,
        []const u8 => .string,
        id_types.SceneEntityId => .entity_ref,
        else => null,
    };
}

fn toValue(comptime kind: std.meta.Tag(FieldKind), raw: anytype) Value {
    return switch (kind) {
        .i32 => .{ .i32 = raw },
        .u32 => .{ .u32 = raw },
        .f32 => .{ .f32 = raw },
        .bool => .{ .bool = raw },
        .vec2 => .{ .vec2 = .{ raw.x, raw.y } },
        .vec3 => .{ .vec3 = .{ raw.x, raw.y, raw.z } },
        .quat => .{ .quat = .{ raw.x, raw.y, raw.z, raw.w } },
        .string => .{ .string = raw },
        .asset_ref => .{ .asset_ref = raw },
        .entity_ref => .{ .entity_ref = raw },
        else => @compileError("unsupported derived kind: " ++ @tagName(kind)),
    };
}

fn valueKindMatches(value: Value, comptime kind: std.meta.Tag(FieldKind)) bool {
    return switch (kind) {
        .i32 => value == .i32,
        .u32 => value == .u32,
        .f32 => value == .f32,
        .bool => value == .bool,
        .vec2 => value == .vec2,
        .vec3 => value == .vec3,
        .quat => value == .quat,
        .string => value == .string,
        .asset_ref => value == .asset_ref,
        .entity_ref => value == .entity_ref,
        else => false,
    };
}

fn fromValue(comptime FT: type, comptime kind: std.meta.Tag(FieldKind), value: Value) !FT {
    if (!valueKindMatches(value, kind)) {
        return error.ValueKindMismatch;
    }

    return switch (kind) {
        .i32 => value.i32,
        .u32 => value.u32,
        .f32 => value.f32,
        .bool => value.bool,
        .vec2 => math.Vec2.new(value.vec2[0], value.vec2[1]),
        .vec3 => math.Vec3.new(value.vec3[0], value.vec3[1], value.vec3[2]),
        .quat => math.Quat{ .x = value.quat[0], .y = value.quat[1], .z = value.quat[2], .w = value.quat[3] },
        .string => value.string,
        .asset_ref => value.asset_ref,
        .entity_ref => value.entity_ref,
        else => @compileError("unsupported derived kind: " ++ @tagName(kind)),
    };
}

fn structFieldDefault(comptime sf: std.builtin.Type.StructField) ?sf.type {
    const ptr = sf.default_value_ptr orelse return null;
    return @as(*const sf.type, @ptrCast(@alignCast(ptr))).*;
}

pub const PersistedField = struct {
    name: [:0]const u8,
    number: u32,
    kind: FieldKind,
    sf: std.builtin.Type.StructField,
    meta: zimp.scene.FieldMeta,

    pub fn Fields(comptime T: type) []const PersistedField {
        const meta: zimp.scene.SchemaMeta = T.schema_meta;
        const struct_fields = @typeInfo(T).@"struct".fields;
        comptime {
            // every meta entry must name a real field
            for (meta.fields) |fm| {
                for (struct_fields) |sf| {
                    if (std.mem.eql(u8, fm.name, sf.name)) {
                        break;
                    }
                } else @compileError(@typeName(T) ++ ".schema_meta names unknown field '" ++ fm.name ++ "'");
            }

            var out: []const PersistedField = &.{};
            for (struct_fields) |sf| {
                const entry: zimp.scene.FieldMeta = for (meta.fields) |fm| {
                    if (std.mem.eql(u8, sf.name, fm.name)) {
                        break fm;
                    }
                } else @compileError(@typeName(T) ++ ".schema_meta is missing field '" ++ sf.name ++ "' (add an entry or mark it transient)");

                const kind = entry.kind_override orelse (autoFieldKind(sf.type) orelse
                    @compileError(@typeName(T) ++ "." ++ sf.name ++ ": type " ++ @typeName(sf.type) ++
                        " needs a kind_override (AssetId fields must declare their asset kind)"));

                for (out) |prev| {
                    if (prev.number == entry.number) {
                        @compileError(@typeName(T) ++ ".schema_meta '" ++ sf.name ++ "' has duplicate number '" ++ entry.number ++ "'");
                    }
                }

                out = out ++ .{PersistedField{
                    .name = sf.name,
                    .number = entry.number,
                    .kind = kind,
                    .sf = sf,
                    .meta = entry,
                }};
            }

            return out;
        }
    }
};

pub fn deriveSchema(comptime T: type) zimp.scene.ComponentSchema {
    const meta: zimp.scene.SchemaMeta = T.schema_meta;
    const pfs = comptime PersistedField.Fields(T);

    const frozen = comptime blk: {
        var fields: [pfs.len]zimp.scene.FieldSchema = undefined;
        for (pfs, 0..) |pf, i| {
            const default_value = dv: {
                if (pf.meta.default_override) |v| {
                    break :dv v;
                }

                if (structFieldDefault(pf.sf)) |raw| {
                    break :dv toValue(std.meta.activeTag(pf.kind), raw);
                }

                @compileError(@typeName(T) ++ "." ++ pf.name ++
                    ": no Zig default value and no default_override in schema_meta");
            };

            fields[i] = .{
                .number = pf.number,
                .name = pf.name,
                .display_name = pf.meta.display_name orelse pf.name,
                .kind = pf.kind,
                .default_value = default_value,
                .editor = pf.meta.editor,
            };
        }

        break :blk fields;
    };

    return .{
        .id = id_types.ComponentTypeId.parseComptime(meta.id),
        .name = meta.name,
        .display_name = meta.display_name orelse meta.name,
        .version = meta.version,
        .fields = &frozen,
    };
}

pub fn deriveCodec(comptime Ecs: type, comptime T: type) ComponentCodec(Ecs) {
    const schema = comptime deriveSchema(T);
    const pfs = comptime PersistedField.Fields(T);

    const Impl = struct {
        fn defaultInstance() T {
            var t: T = undefined;
            inline for (@typeInfo(T).@"struct".fields) |sf| {
                if (comptime structFieldDefault(sf)) |d| {
                    @field(t, sf.name) = d;
                } else {
                    inline for (pfs) |pf| {
                        if (comptime std.mem.eql(u8, pf.name, sf.name)) {
                            @field(t, sf.name) = fromValue(
                                sf.type,
                                comptime std.meta.activeTag(pf.kind),
                                pf.meta.default_override.?,
                            ) catch unreachable;
                        }
                    }
                }
            }

            return t;
        }

        fn attachDefault(world: *Ecs.World, entity: zcs.EntityID, _: std.mem.Allocator) !void {
            try world.addComponent(entity, T, defaultInstance());
        }

        fn attach(world: *Ecs.World, entity: zcs.EntityID, _: std.mem.Allocator, data: zimp.scene.SceneComponentData) !void {
            var instance = defaultInstance();
            for (data.fields) |sf| {
                const applied = inline for (pfs) |pf| {
                    if (pf.number == sf.number) {
                        @field(instance, pf.name) = try fromValue(
                            pf.sf.type,
                            comptime std.meta.activeTag(pf.kind),
                            sf.value,
                        );
                        break true;
                    }
                } else false;

                if (!applied) {
                    return codec.CodecError.UnknownFieldNumber;
                }
            }

            try world.addComponent(entity, T, instance);
        }

        fn detach(world: *Ecs.World, entity: zcs.EntityID) !void {
            try world.removeComponent(entity, T);
        }

        fn readDocument(world: *Ecs.World, entity: zcs.EntityID, allocator: std.mem.Allocator) !zimp.scene.SceneComponentData {
            const comp = world.getComponent(entity, T) orelse return codec.CodecError.ComponentMissing;
            const fields = try allocator.alloc(zimp.scene.SceneField, pfs.len);
            for (fields) |*field| {
                field.* = .{ .number = 0, .value = .{ .none = {} } };
            }
            errdefer {
                var data = zimp.scene.SceneComponentData{ .component = schema.id, .fields = fields };
                data.deinit(allocator);
            }

            inline for (pfs, 0..) |pf, i| {
                fields[i] = .{
                    .number = pf.number,
                    .value = try toValue(comptime std.meta.activeTag(pf.kind), @field(comp.*, pf.name)).clone(allocator),
                };
            }

            return .{ .component = schema.id, .fields = fields };
        }

        fn writeField(world: *Ecs.World, entity: zcs.EntityID, number: u32, value: zimp.scene.Value) !void {
            const comp = world.getComponent(entity, T) orelse return codec.CodecError.ComponentMissing;
            inline for (pfs) |pf| {
                if (pf.number == number) {
                    @field(comp.*, pf.name) = try fromValue(
                        pf.sf.type,
                        comptime std.meta.activeTag(pf.kind),
                        value,
                    );
                    return;
                }
            }

            return codec.CodecError.UnknownFieldNumber;
        }
    };

    return .{
        .schema = schema,
        .attachDefault = &Impl.attachDefault,
        .attach = &Impl.attach,
        .detach = &Impl.detach,
        .readDocument = &Impl.readDocument,
        .writeField = &Impl.writeField,
    };
}

const testing = std.testing;

const test_component_id = "12345678-9abc-4def-8012-3456789abcde";

const SchemaFixture = struct {
    enabled: bool = true,
    count: i32 = -3,
    layer: u32 = 4,
    opacity: f32 = 0.5,
    offset: math.Vec2 = math.Vec2.new(1, 2),
    position: math.Vec3 = math.Vec3.new(3, 4, 5),
    rotation: math.Quat = .{ .x = 0.1, .y = 0.2, .z = 0.3, .w = 0.4 },
    label: []const u8 = "fixture",
    target: id_types.SceneEntityId = id_types.SceneEntityId.parseComptime("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"),
    material: id_types.AssetId = id_types.AssetId.zero,

    pub const schema_meta: zimp.scene.SchemaMeta = .{
        .id = test_component_id,
        .name = "SchemaFixture",
        .display_name = "Schema Fixture",
        .version = 2,
        .fields = &.{
            .{ .name = "enabled", .number = 1, .display_name = "Enabled" },
            .{ .name = "count", .number = 2, .editor = .{ .min = -10, .max = 10, .step = 1, .slider = true } },
            .{ .name = "layer", .number = 3, .default_override = .{ .u32 = 9 } },
            .{ .name = "opacity", .number = 4 },
            .{ .name = "offset", .number = 5 },
            .{ .name = "position", .number = 6 },
            .{ .name = "rotation", .number = 7 },
            .{ .name = "label", .number = 8, .editor = .{ .multiline = true } },
            .{ .name = "target", .number = 9 },
            .{ .name = "material", .number = 10, .kind_override = .{ .asset_ref = .material }, .default_override = .{ .asset_ref = id_types.AssetId.zero } },
        },
    };
};

fn expectField(
    field: zimp.scene.FieldSchema,
    number: u32,
    name: []const u8,
    display_name: []const u8,
    kind_tag: std.meta.Tag(FieldKind),
    default_tag: std.meta.Tag(Value),
) !void {
    try testing.expectEqual(number, field.number);
    try testing.expectEqualStrings(name, field.name);
    try testing.expectEqualStrings(display_name, field.display_name);
    try testing.expectEqual(kind_tag, std.meta.activeTag(field.kind));
    try testing.expectEqual(default_tag, std.meta.activeTag(field.default_value));
}

test "deriveSchema builds component schema from Zig fields and metadata" {
    const schema = deriveSchema(SchemaFixture);

    try testing.expect(schema.id.eql(id_types.ComponentTypeId.parseComptime(test_component_id)));
    try testing.expectEqualStrings("SchemaFixture", schema.name);
    try testing.expectEqualStrings("Schema Fixture", schema.display_name);
    try testing.expectEqual(@as(u32, 2), schema.version);
    try testing.expectEqual(@as(usize, 10), schema.fields.len);

    try expectField(schema.fields[0], 1, "enabled", "Enabled", .bool, .bool);
    try testing.expectEqual(true, schema.fields[0].default_value.bool);

    try expectField(schema.fields[1], 2, "count", "count", .i32, .i32);
    try testing.expectEqual(@as(i32, -3), schema.fields[1].default_value.i32);
    try testing.expectEqual(@as(?f32, -10), schema.fields[1].editor.min);
    try testing.expectEqual(@as(?f32, 10), schema.fields[1].editor.max);
    try testing.expectEqual(@as(?f32, 1), schema.fields[1].editor.step);
    try testing.expect(schema.fields[1].editor.slider);

    try expectField(schema.fields[2], 3, "layer", "layer", .u32, .u32);
    try testing.expectEqual(@as(u32, 9), schema.fields[2].default_value.u32);

    try expectField(schema.fields[3], 4, "opacity", "opacity", .f32, .f32);
    try testing.expectEqual(@as(f32, 0.5), schema.fields[3].default_value.f32);

    try expectField(schema.fields[4], 5, "offset", "offset", .vec2, .vec2);
    try testing.expectEqual([2]f32{ 1, 2 }, schema.fields[4].default_value.vec2);

    try expectField(schema.fields[5], 6, "position", "position", .vec3, .vec3);
    try testing.expectEqual([3]f32{ 3, 4, 5 }, schema.fields[5].default_value.vec3);

    try expectField(schema.fields[6], 7, "rotation", "rotation", .quat, .quat);
    try testing.expectEqual([4]f32{ 0.1, 0.2, 0.3, 0.4 }, schema.fields[6].default_value.quat);

    try expectField(schema.fields[7], 8, "label", "label", .string, .string);
    try testing.expectEqualStrings("fixture", schema.fields[7].default_value.string);
    try testing.expect(schema.fields[7].editor.multiline);

    try expectField(schema.fields[8], 9, "target", "target", .entity_ref, .entity_ref);
    try testing.expect(schema.fields[8].default_value.entity_ref.eql(id_types.SceneEntityId.parseComptime("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")));

    try expectField(schema.fields[9], 10, "material", "material", .asset_ref, .asset_ref);
    try testing.expectEqual(zimp.AssetKind.material, schema.fields[9].kind.asset_ref);
    try testing.expect(schema.fields[9].default_value.asset_ref.eql(id_types.AssetId.zero));
}

test "PersistedField.Fields exposes field numbers and overridden kinds" {
    const fields = comptime PersistedField.Fields(SchemaFixture);

    try testing.expectEqual(@as(usize, 10), fields.len);
    try testing.expectEqualStrings("enabled", fields[0].name);
    try testing.expectEqual(@as(u32, 1), fields[0].number);
    try testing.expectEqual(.bool, std.meta.activeTag(fields[0].kind));

    try testing.expectEqualStrings("material", fields[9].name);
    try testing.expectEqual(@as(u32, 10), fields[9].number);
    try testing.expectEqual(.asset_ref, std.meta.activeTag(fields[9].kind));
    try testing.expectEqual(zimp.AssetKind.material, fields[9].kind.asset_ref);
}

test "value conversion helpers map supported scalar and math values" {
    try testing.expectEqual(Value{ .bool = false }, toValue(.bool, false));
    try testing.expectEqual(Value{ .i32 = -8 }, toValue(.i32, @as(i32, -8)));
    try testing.expectEqual(Value{ .u32 = 8 }, toValue(.u32, @as(u32, 8)));
    try testing.expectEqual(Value{ .f32 = 1.25 }, toValue(.f32, @as(f32, 1.25)));
    try testing.expectEqual(Value{ .vec2 = .{ 1, 2 } }, toValue(.vec2, math.Vec2.new(1, 2)));
    try testing.expectEqual(Value{ .vec3 = .{ 3, 4, 5 } }, toValue(.vec3, math.Vec3.new(3, 4, 5)));
    try testing.expectEqual(Value{ .quat = .{ 0, 0, 0, 1 } }, toValue(.quat, math.Quat.identity));
    try testing.expectEqual(Value{ .string = "name" }, toValue(.string, "name"));
    try testing.expectEqual(Value{ .entity_ref = id_types.SceneEntityId.zero }, toValue(.entity_ref, id_types.SceneEntityId.zero));

    const vec = try fromValue(math.Vec3, .vec3, .{ .vec3 = .{ 6, 7, 8 } });
    try testing.expectEqual(math.Vec3.new(6, 7, 8), vec);
    try testing.expectError(error.ValueKindMismatch, fromValue(bool, .bool, .{ .i32 = 1 }));
}

const CodecFixtureEcs = @import("../ecs/world.zig").GameEcs(&.{SchemaFixture});

fn expectSchemaFixtureDefaults(actual: *const SchemaFixture) !void {
    try testing.expectEqual(true, actual.enabled);
    try testing.expectEqual(@as(i32, -3), actual.count);
    try testing.expectEqual(@as(u32, 4), actual.layer);
    try testing.expectEqual(@as(f32, 0.5), actual.opacity);
    try testing.expectEqual(math.Vec2.new(1, 2), actual.offset);
    try testing.expectEqual(math.Vec3.new(3, 4, 5), actual.position);
    try testing.expectEqual(math.Quat{ .x = 0.1, .y = 0.2, .z = 0.3, .w = 0.4 }, actual.rotation);
    try testing.expectEqualStrings("fixture", actual.label);
    try testing.expect(actual.target.eql(id_types.SceneEntityId.parseComptime("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")));
    try testing.expect(actual.material.eql(id_types.AssetId.zero));
}

fn expectSchemaFixtureEqual(expected: *const SchemaFixture, actual: *const SchemaFixture) !void {
    try testing.expectEqual(expected.enabled, actual.enabled);
    try testing.expectEqual(expected.count, actual.count);
    try testing.expectEqual(expected.layer, actual.layer);
    try testing.expectEqual(expected.opacity, actual.opacity);
    try testing.expectEqual(expected.offset, actual.offset);
    try testing.expectEqual(expected.position, actual.position);
    try testing.expectEqual(expected.rotation, actual.rotation);
    try testing.expectEqualStrings(expected.label, actual.label);
    try testing.expect(actual.target.eql(expected.target));
    try testing.expect(actual.material.eql(expected.material));
}

fn expectSceneField(field: zimp.scene.SceneField, number: u32, expected: Value) !void {
    try testing.expectEqual(number, field.number);
    switch (expected) {
        .string => |str| {
            try testing.expect(field.value == .string);
            try testing.expectEqualStrings(str, field.value.string);
        },
        else => try testing.expectEqual(expected, field.value),
    }
}

test "deriveCodec attaches default component and detaches it" {
    const derived = deriveCodec(CodecFixtureEcs, SchemaFixture);
    var world = CodecFixtureEcs.World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.spawn();
    try derived.attachDefault(&world, entity, testing.allocator);

    try expectSchemaFixtureDefaults(world.getComponent(entity, SchemaFixture).?);

    try derived.detach(&world, entity);
    try testing.expect(world.getComponent(entity, SchemaFixture) == null);
}

test "deriveCodec attaches document data over component defaults" {
    const derived = deriveCodec(CodecFixtureEcs, SchemaFixture);
    var world = CodecFixtureEcs.World.init(testing.allocator);
    defer world.deinit();

    const target = id_types.SceneEntityId.parseComptime("bbbbbbbb-cccc-4ddd-8eee-ffffffffffff");
    const material = id_types.AssetId.parseComptime("11111111-2222-4333-8444-555555555555");
    const entity = try world.spawn();
    var fields = [_]zimp.scene.SceneField{
        .{ .number = 1, .value = .{ .bool = false } },
        .{ .number = 2, .value = .{ .i32 = 42 } },
        .{ .number = 3, .value = .{ .u32 = 12 } },
        .{ .number = 4, .value = .{ .f32 = 0.875 } },
        .{ .number = 5, .value = .{ .vec2 = .{ -1, -2 } } },
        .{ .number = 6, .value = .{ .vec3 = .{ 6, 7, 8 } } },
        .{ .number = 7, .value = .{ .quat = .{ 0, 0, 0, 1 } } },
        .{ .number = 8, .value = .{ .string = "document" } },
        .{ .number = 9, .value = .{ .entity_ref = target } },
        .{ .number = 10, .value = .{ .asset_ref = material } },
    };
    try derived.attach(&world, entity, testing.allocator, .{
        .component = derived.schema.id,
        .fields = &fields,
    });

    const actual = world.getComponent(entity, SchemaFixture).?;
    try testing.expectEqual(false, actual.enabled);
    try testing.expectEqual(@as(i32, 42), actual.count);
    try testing.expectEqual(@as(u32, 12), actual.layer);
    try testing.expectEqual(@as(f32, 0.875), actual.opacity);
    try testing.expectEqual(math.Vec2.new(-1, -2), actual.offset);
    try testing.expectEqual(math.Vec3.new(6, 7, 8), actual.position);
    try testing.expectEqual(math.Quat.identity, actual.rotation);
    try testing.expectEqualStrings("document", actual.label);
    try testing.expect(actual.target.eql(target));
    try testing.expect(actual.material.eql(material));
}

test "deriveCodec writes fields and reads scene component data" {
    const derived = deriveCodec(CodecFixtureEcs, SchemaFixture);
    var world = CodecFixtureEcs.World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.spawn();
    try derived.attachDefault(&world, entity, testing.allocator);
    try derived.writeField(&world, entity, 1, .{ .bool = false });
    try derived.writeField(&world, entity, 6, .{ .vec3 = .{ 9, 8, 7 } });
    try derived.writeField(&world, entity, 8, .{ .string = "updated" });

    const live = world.getComponent(entity, SchemaFixture).?;
    try testing.expectEqual(false, live.enabled);
    try testing.expectEqual(math.Vec3.new(9, 8, 7), live.position);
    try testing.expectEqualStrings("updated", live.label);

    var data = try derived.readDocument(&world, entity, testing.allocator);
    defer data.deinit(testing.allocator);

    try testing.expect(data.component.eql(derived.schema.id));
    try testing.expectEqual(@as(usize, 10), data.fields.len);
    try expectSceneField(data.fields[0], 1, .{ .bool = false });
    try expectSceneField(data.fields[1], 2, .{ .i32 = -3 });
    try expectSceneField(data.fields[2], 3, .{ .u32 = 4 });
    try expectSceneField(data.fields[5], 6, .{ .vec3 = .{ 9, 8, 7 } });
    try expectSceneField(data.fields[7], 8, .{ .string = "updated" });

    const clone = try world.spawn();
    try derived.attach(&world, clone, testing.allocator, data);
    const cloned = world.getComponent(clone, SchemaFixture).?;
    try expectSchemaFixtureEqual(live, cloned);
}

test "deriveCodec reports missing components and invalid document fields" {
    const derived = deriveCodec(CodecFixtureEcs, SchemaFixture);
    var world = CodecFixtureEcs.World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.spawn();
    try testing.expectError(codec.CodecError.ComponentMissing, derived.writeField(&world, entity, 1, .{ .bool = false }));
    try testing.expectError(codec.CodecError.ComponentMissing, derived.readDocument(&world, entity, testing.allocator));

    var unknown_fields = [_]zimp.scene.SceneField{.{ .number = 99, .value = .{ .bool = false } }};
    try testing.expectError(codec.CodecError.UnknownFieldNumber, derived.attach(&world, entity, testing.allocator, .{
        .component = derived.schema.id,
        .fields = &unknown_fields,
    }));

    var mismatch_fields = [_]zimp.scene.SceneField{.{ .number = 1, .value = .{ .i32 = 1 } }};
    try testing.expectError(codec.CodecError.ValueKindMismatch, derived.attach(&world, entity, testing.allocator, .{
        .component = derived.schema.id,
        .fields = &mismatch_fields,
    }));

    try derived.attachDefault(&world, entity, testing.allocator);
    try testing.expectError(codec.CodecError.UnknownFieldNumber, derived.writeField(&world, entity, 99, .{ .bool = false }));
    try testing.expectError(codec.CodecError.ValueKindMismatch, derived.writeField(&world, entity, 1, .{ .i32 = 1 }));
}
