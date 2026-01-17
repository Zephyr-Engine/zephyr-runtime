const std = @import("std");
const Vec3 = @import("../root.zig").Vec3;

const VertexArray = @import("../graphics/opengl_vertex_array.zig").VertexArray;
const Material = @import("material.zig").Material;
const obj = @import("object.zig");

pub const Model = struct {
    vao: VertexArray,
    material: *const Material,
    position: Vec3,

    pub fn init(allocator: std.mem.Allocator, mesh_data: []const u8, material: *const Material, position: Vec3) !Model {
        var mesh = try obj.parse(allocator, mesh_data);
        const vao = VertexArray.init(mesh.vertices, mesh.indices);
        mesh.deinit();

        vao.setLayout(material.shader.buffer_layout);

        return .{
            .vao = vao,
            .material = material,
            .position = position,
        };
    }

    pub fn draw(self: *Model) void {
        self.vao.draw();
    }
};
