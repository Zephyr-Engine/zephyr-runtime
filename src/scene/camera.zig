const std = @import("std");
const math = @import("../core/math.zig");
const components = @import("../ecs/components.zig");
const ecs = @import("../ecs/world.zig");

const Mat4 = math.Mat4;

pub const ActiveCamera = struct {
    entity: ecs.EntityID,
};

const expectApproxEq = std.testing.expectApproxEqAbs;
const tolerance: f32 = 1e-4;

pub fn setActive(world: *ecs.World, entity: ecs.EntityID) !void {
    if (world.getComponent(entity, components.TransformComponent) == null or
        world.getComponent(entity, components.CameraComponent) == null)
    {
        return error.InvalidCamera;
    }
    try world.setResource(ActiveCamera, .{ .entity = entity });
}

pub fn active(world: *ecs.World) ?ecs.EntityID {
    const selection = world.getResourceOrNull(ActiveCamera) orelse return null;
    const entity = selection.entity;
    if (world.getComponent(entity, components.TransformComponent) == null or
        world.getComponent(entity, components.CameraComponent) == null)
    {
        return null;
    }
    return entity;
}

test "camera projection uses the render-view aspect" {
    const camera = components.CameraComponent{};
    const projection = camera.projectionMatrix(2.0);
    const expected = Mat4.createPerspective(std.math.pi / 4.0, 2.0, 0.1, 1000.0);

    for (0..4) |row| {
        for (0..4) |col| {
            try expectApproxEq(projection.fields[row][col], expected.fields[row][col], tolerance);
        }
    }
}

test "active camera is an explicit world selection" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const first = try world.spawnWith(.{
        components.TransformComponent{},
        components.CameraComponent{},
    });
    const second = try world.spawnWith(.{
        components.TransformComponent{},
        components.CameraComponent{},
    });

    try setActive(&world, first);
    try std.testing.expectEqual(first, active(&world).?);

    try setActive(&world, second);
    try std.testing.expectEqual(second, active(&world).?);
}

test "active camera must have camera and transform components" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = try world.spawn();
    try std.testing.expectError(error.InvalidCamera, setActive(&world, entity));
}
