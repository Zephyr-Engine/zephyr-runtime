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
        detach: *const fn (*Ecs.World, zcs.EntityID) anyerror!void,

        readDocument: *const fn (*Ecs.World, zcs.EntityID, std.mem.Allocator) anyerror!SceneComponentData,
        writeField: *const fn (*Ecs.World, zcs.EntityID, std.mem.Allocator, Value) anyerror!void,
    };
}
