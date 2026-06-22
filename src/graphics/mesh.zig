const std = @import("std");
const zimp = @import("zimp");

const VertexArray = @import("opengl/vertex_array.zig").VertexArray;
const IndexBuffer = @import("opengl/buffer.zig").IndexBuffer;
const ZMesh = zimp.ZMesh;

pub const Mesh = struct {
    vao: VertexArray,
    aabb_min: [3]f32,
    aabb_max: [3]f32,

    pub fn loadFromZMesh(mesh: ZMesh) !Mesh {
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
            .aabb_min = mesh.aabb_min,
            .aabb_max = mesh.aabb_max,
        };
    }

    pub fn draw(self: *const Mesh) void {
        self.vao.draw();
    }

    pub fn deinit(self: *Mesh) void {
        self.vao.deinit();
    }
};
