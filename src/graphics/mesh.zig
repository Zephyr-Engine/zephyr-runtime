const std = @import("std");
const zimp = @import("zimp");

const IndexBuffer = @import("opengl/buffer.zig").IndexBuffer;
const VertexArray = @import("opengl/vertex_array.zig");
const math = @import("../core/math.zig");
const MeshPart = zimp.formats.zmesh.MeshPart;
const ZMesh = zimp.ZMesh;

const Mesh = @This();

allocator: std.mem.Allocator,
material_ids: []zimp.AssetId,
parts: []Part,

pub const Part = struct {
    vao: VertexArray,
    transform: math.Mat4,

    bounds_min: [3]f32,
    bounds_max: [3]f32,

    submeshes: []Submesh,

    pub fn drawSubmesh(self: *const Part, submesh: *const Submesh) void {
        self.vao.drawRange(
            submesh.index_offset,
            submesh.index_count,
        );
    }

    pub fn deinit(self: *Part, allocator: std.mem.Allocator) void {
        allocator.free(self.submeshes);
        self.vao.deinit();
    }
};

pub const Submesh = struct {
    material_index: u16,
    index_offset: u32,
    index_count: u32,
};

pub fn loadFromZMesh(allocator: std.mem.Allocator, model: *const ZMesh, material_ids: []zimp.AssetId) !Mesh {
    const parts = try allocator.alloc(Part, model.parts.len);
    errdefer allocator.free(parts);

    var initialized: usize = 0;
    errdefer for (parts[0..initialized]) |*part| part.deinit(allocator);

    for (model.parts, parts) |source, *part| {
        part.* = try loadPart(allocator, source.mesh, mat4FromArray(source.transform));
        initialized += 1;
    }

    return .{
        .material_ids = material_ids,
        .allocator = allocator,
        .parts = parts,
    };
}

fn loadPart(allocator: std.mem.Allocator, mesh: MeshPart, transform: math.Mat4) !Part {
    var vao = try VertexArray.init();
    errdefer vao.deinit();

    const submeshes = try allocator.alloc(Submesh, mesh.submeshes.len);
    errdefer allocator.free(submeshes);

    for (mesh.submeshes, submeshes) |source_submesh, *runtime_submesh| {
        runtime_submesh.* = .{
            .material_index = source_submesh.material_index,
            .index_offset = source_submesh.index_offset,
            .index_count = source_submesh.index_count,
        };
    }

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
        .bounds_max = mesh.aabb_max,
        .bounds_min = mesh.aabb_min,
        .submeshes = submeshes,
    };
}

pub fn materialIdForSlot(self: *const Mesh, slot: u16) ?zimp.AssetId {
    const index: usize = @intCast(slot);
    if (index >= self.material_ids.len) {
        return null;
    }

    return self.material_ids[index];
}

pub fn deinit(self: *Mesh) void {
    for (self.parts) |*part| {
        part.deinit(self.allocator);
    }
    self.allocator.free(self.parts);
    self.allocator.free(self.material_ids);
}

fn mat4FromArray(values: [16]f32) math.Mat4 {
    return .{ .fields = .{
        .{ values[0], values[1], values[2], values[3] },
        .{ values[4], values[5], values[6], values[7] },
        .{ values[8], values[9], values[10], values[11] },
        .{ values[12], values[13], values[14], values[15] },
    } };
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
    const entity = math.Mat4.createScale(2, 2, 2);
    const transformed = @import("../core/math.zig").Vec3.zero.transformPosition(part.mul(entity));
    try std.testing.expectEqual(@as(f32, 2), transformed.x);
}
