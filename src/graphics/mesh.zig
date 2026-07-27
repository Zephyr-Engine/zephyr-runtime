const std = @import("std");
const zimp = @import("zimp");

const ZMesh = zimp.ZMesh;
const IndexBuffer = @import("opengl/buffer.zig").IndexBuffer;
const VertexArray = @import("opengl/vertex_array.zig").VertexArray;

pub const Mesh = struct {
    vaos: []VertexArray,
    aabb_min: [3]f32,
    aabb_max: [3]f32,
    allocator: std.mem.Allocator,

    pub fn loadFromZmesh(allocator: std.mem.Allocator, mesh: ZMesh) !Mesh {
        const vaos = try allocator.alloc(VertexArray, mesh.parts.len);

        var aabb_min = mesh.parts[0].mesh.aabb_min;
        var aabb_max = mesh.parts[0].mesh.aabb_max;
        for (mesh.parts, vaos) |part, *vao| {
            vao.* = try loadPart(&part.mesh);
            for (0..3) |axis| {
                aabb_min[axis] = @min(aabb_min[axis], part.mesh.aabb_min[axis]);
                aabb_max[axis] = @max(aabb_max[axis], part.mesh.aabb_max[axis]);
            }
        }

        return .{
            .vaos = vaos,
            .aabb_min = aabb_min,
            .aabb_max = aabb_max,
            .allocator = allocator,
        };
    }

    pub fn loadPart(mesh: *const zimp.formats.zmesh.MeshPart) !VertexArray {
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

        return vao;
    }

    pub fn draw(self: *const Mesh) void {
        for (self.vaos) |vao| {
            vao.draw();
        }
    }

    pub fn deinit(self: *Mesh) void {
        for (self.vaos) |*vao| {
            vao.deinit();
        }
        self.allocator.free(self.vaos);
    }
};
