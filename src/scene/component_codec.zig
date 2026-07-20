const std = @import("std");

const zcs = @import("zcs");
const zimp = @import("zimp");

const SceneComponentData = zimp.scene.SceneComponentData;
const ComponentSchema = zimp.scene.ComponentSchema;
const Value = zimp.scene.Value;

pub const CodecError = error{
    ComponentMissing,
    UnknownFieldNumber,
    ValueKindMismatch,
};

pub fn ComponentCodec(comptime Ecs: type) type {
    return struct {
        schema: ComponentSchema,

        attachDefault: *const fn (*Ecs.World, zcs.EntityID, std.mem.Allocator) anyerror!void,
        attach: *const fn (*Ecs.World, zcs.EntityID, std.mem.Allocator, SceneComponentData) anyerror!void,
        detach: *const fn (*Ecs.World, zcs.EntityID, std.mem.Allocator) anyerror!void,

        readDocument: *const fn (*Ecs.World, zcs.EntityID, std.mem.Allocator) anyerror!SceneComponentData,
        writeField: *const fn (*Ecs.World, zcs.EntityID, std.mem.Allocator, u32, Value) anyerror!void,
    };
}

const testing = std.testing;

const TestEcs = struct {
    const World = struct {
        attached_defaults: u32 = 0,
        attached: u32 = 0,
        detached: u32 = 0,
        read_documents: u32 = 0,
        written_fields: u32 = 0,
        last_entity: zcs.EntityID = zcs.EntityID.nil,
        last_component: zimp.id.types.ComponentTypeId = zimp.id.types.ComponentTypeId.zero,
        last_value: Value = .{ .none = {} },
    };
};

const test_component_id = zimp.id.types.ComponentTypeId.parseComptime("12345678-9abc-4def-8012-3456789abcde");

fn testSchema() ComponentSchema {
    return .{
        .id = test_component_id,
        .name = "TestComponent",
        .display_name = "Test Component",
        .version = 1,
        .fields = &.{.{
            .number = 1,
            .name = "enabled",
            .display_name = "Enabled",
            .kind = .bool,
            .default_value = .{ .bool = false },
            .editor = .{},
        }},
    };
}

fn attachDefault(world: *TestEcs.World, entity: zcs.EntityID, _: std.mem.Allocator) !void {
    world.attached_defaults += 1;
    world.last_entity = entity;
}

fn attach(world: *TestEcs.World, entity: zcs.EntityID, _: std.mem.Allocator, data: SceneComponentData) !void {
    world.attached += 1;
    world.last_entity = entity;
    world.last_component = data.component;
}

fn detach(world: *TestEcs.World, entity: zcs.EntityID, _: std.mem.Allocator) !void {
    world.detached += 1;
    world.last_entity = entity;
}

fn readDocument(world: *TestEcs.World, entity: zcs.EntityID, allocator: std.mem.Allocator) !SceneComponentData {
    world.read_documents += 1;
    world.last_entity = entity;

    const fields = try allocator.alloc(zimp.scene.value.SceneField, 1);
    fields[0] = .{ .number = 1, .value = .{ .bool = true } };
    return .{
        .component = test_component_id,
        .fields = fields,
    };
}

fn writeField(world: *TestEcs.World, entity: zcs.EntityID, _: std.mem.Allocator, _: u32, value: Value) !void {
    world.written_fields += 1;
    world.last_entity = entity;
    world.last_value = value;
}

test "ComponentCodec stores schema and dispatches callbacks" {
    const Codec = ComponentCodec(TestEcs);
    const codec = Codec{
        .schema = testSchema(),
        .attachDefault = attachDefault,
        .attach = attach,
        .detach = detach,
        .readDocument = readDocument,
        .writeField = writeField,
    };

    try testing.expect(codec.schema.id.eql(test_component_id));
    try testing.expectEqualStrings("TestComponent", codec.schema.name);
    try testing.expectEqual(@as(usize, 1), codec.schema.fields.len);

    var world = TestEcs.World{};
    const entity: zcs.EntityID = .{ .index = 7, .generation = 2 };
    try codec.attachDefault(&world, entity, testing.allocator);
    try testing.expectEqual(@as(u32, 1), world.attached_defaults);
    try testing.expect(world.last_entity.eql(entity));

    const data = SceneComponentData{
        .component = test_component_id,
        .fields = &.{},
    };
    try codec.attach(&world, entity, testing.allocator, data);
    try testing.expectEqual(@as(u32, 1), world.attached);
    try testing.expect(world.last_component.eql(test_component_id));

    try codec.writeField(&world, entity, testing.allocator, 1, .{ .i32 = -4 });
    try testing.expectEqual(@as(u32, 1), world.written_fields);
    try testing.expectEqual(Value{ .i32 = -4 }, world.last_value);

    var read = try codec.readDocument(&world, entity, testing.allocator);
    defer read.deinit(testing.allocator);
    try testing.expectEqual(@as(u32, 1), world.read_documents);
    try testing.expect(read.component.eql(test_component_id));
    try testing.expectEqual(@as(usize, 1), read.fields.len);
    try testing.expectEqual(Value{ .bool = true }, read.fields[0].value);

    try codec.detach(&world, entity, testing.allocator);
    try testing.expectEqual(@as(u32, 1), world.detached);
    try testing.expect(world.last_entity.eql(entity));
}
