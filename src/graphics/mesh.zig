const std = @import("std");
const zimp = @import("zimp");

const VertexArray = @import("opengl/vertex_array.zig").VertexArray;
const IndexBuffer = @import("opengl/buffer.zig").IndexBuffer;
const ZMesh = zimp.ZMesh;
const MeshPart = zimp.formats.zmesh.MeshPart;
const Mat4 = @import("../core/math.zig").Mat4;

pub const Mesh = struct {
    allocator: std.mem.Allocator,
    parts: []Part,
    aabb_min: [3]f32,
    aabb_max: [3]f32,

    pub const Part = struct {
        vao: VertexArray,
        transform: Mat4,

        pub fn draw(self: *const Part) void {
            self.vao.draw();
        }
    };

    pub fn loadFromZMesh(allocator: std.mem.Allocator, model: ZMesh) !Mesh {
        const parts = try allocator.alloc(Part, model.parts.len);
        errdefer allocator.free(parts);

        var initialized: usize = 0;
        errdefer for (parts[0..initialized]) |*part| part.vao.deinit();

        var aabb_min = [3]f32{ std.math.inf(f32), std.math.inf(f32), std.math.inf(f32) };
        var aabb_max = [3]f32{ -std.math.inf(f32), -std.math.inf(f32), -std.math.inf(f32) };
        for (model.parts, parts) |source, *part| {
            part.* = try loadPart(source.mesh, mat4FromArray(source.transform));
            initialized += 1;
            expandBounds(&aabb_min, &aabb_max, source.mesh, part.transform);
        }

        return .{
            .allocator = allocator,
            .parts = parts,
            .aabb_min = aabb_min,
            .aabb_max = aabb_max,
        };
    }

    fn loadPart(mesh: MeshPart, transform: Mat4) !Part {
        var vao = try VertexArray.init();
        errdefer vao.deinit();

        var location: u32 = 1;
        try vao.addStream(
            std.mem.sliceAsBytes(mesh.positions),
            .{ .location = 0, .data_type = .Float3, .normalized = false },
        );

        if (mesh.normals) |normals| {
            try vao.addStream(
                std.mem.sliceAsBytes(normals),
                .{ .location = location, .data_type = .Short2, .normalized = true },
            );
            location += 1;
        }

        if (mesh.uv0) |uvs| {
            try vao.addStream(
                std.mem.sliceAsBytes(uvs),
                .{ .location = location, .data_type = .UShort2, .normalized = true },
            );
            location += 1;
        }

        if (mesh.uv1) |uvs| {
            try vao.addStream(
                std.mem.sliceAsBytes(uvs),
                .{ .location = location, .data_type = .UShort2, .normalized = true },
            );
            location += 1;
        }

        if (mesh.tangents) |tangents| {
            try vao.addStream(
                std.mem.sliceAsBytes(tangents),
                .{ .location = location, .data_type = .Half4, .normalized = false },
            );
            location += 1;
        }

        if (mesh.joint_indices) |joints| {
            try vao.addStream(
                std.mem.sliceAsBytes(joints),
                .{ .location = location, .data_type = .UShort4, .normalized = false },
            );
            location += 1;
        }

        if (mesh.joint_weights) |weights| {
            try vao.addStream(
                std.mem.sliceAsBytes(weights),
                .{ .location = location, .data_type = .Half4, .normalized = false },
            );
        }

        if (mesh.indices_u16) |indices| {
            vao.setIndexBuffer(try IndexBuffer.initU16(indices));
        } else if (mesh.indices_u32) |indices| {
            vao.setIndexBuffer(try IndexBuffer.initU32(indices));
        }

        return .{
            .vao = vao,
            .transform = transform,
        };
    }

    pub fn draw(self: *const Mesh) void {
        for (self.parts) |*part| part.draw();
    }

    pub fn deinit(self: *Mesh) void {
        for (self.parts) |*part| part.vao.deinit();
        self.allocator.free(self.parts);
        self.* = undefined;
    }
};

fn mat4FromArray(values: [16]f32) Mat4 {
    return .{ .fields = .{
        .{ values[0], values[1], values[2], values[3] },
        .{ values[4], values[5], values[6], values[7] },
        .{ values[8], values[9], values[10], values[11] },
        .{ values[12], values[13], values[14], values[15] },
    } };
}

fn expandBounds(min: *[3]f32, max: *[3]f32, mesh: MeshPart, transform: Mat4) void {
    for (0..8) |corner_index| {
        const corner = @import("../core/math.zig").Vec3.new(
            if (corner_index & 1 == 0) mesh.aabb_min[0] else mesh.aabb_max[0],
            if (corner_index & 2 == 0) mesh.aabb_min[1] else mesh.aabb_max[1],
            if (corner_index & 4 == 0) mesh.aabb_min[2] else mesh.aabb_max[2],
        ).transformPosition(transform);
        min[0] = @min(min[0], corner.x);
        min[1] = @min(min[1], corner.y);
        min[2] = @min(min[2], corner.z);
        max[0] = @max(max[0], corner.x);
        max[1] = @max(max[1], corner.y);
        max[2] = @max(max[2], corner.z);
    }
}

test "mat4FromArray preserves model part translation" {
    const matrix = mat4FromArray(.{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        2, 3, 4, 1,
    });
    const transformed = @import("../core/math.zig").Vec3.zero.transformPosition(matrix);
    try std.testing.expectEqual(@as(f32, 2), transformed.x);
    try std.testing.expectEqual(@as(f32, 3), transformed.y);
    try std.testing.expectEqual(@as(f32, 4), transformed.z);
}

test "mesh part transform is applied before the entity transform" {
    const part = mat4FromArray(.{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        1, 0, 0, 1,
    });
    const entity = Mat4.createScale(2, 2, 2);
    const transformed = @import("../core/math.zig").Vec3.zero.transformPosition(part.mul(entity));
    try std.testing.expectEqual(@as(f32, 2), transformed.x);
}
