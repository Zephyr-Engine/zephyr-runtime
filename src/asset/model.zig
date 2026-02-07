const std = @import("std");
const Transform = @import("transform.zig").Transform;

const VertexArray = @import("../graphics/opengl_vertex_array.zig").VertexArray;
const MaterialInstance = @import("material.zig").MaterialInstance;
const obj = @import("object.zig");

pub const Model = struct {
    vao: VertexArray,
    material: *const MaterialInstance,
    transform: Transform,

    pub fn init(allocator: std.mem.Allocator, mesh_data: []const u8, material: *const MaterialInstance, transform: Transform) !Model {
        var mesh = try obj.parse(allocator, mesh_data);
        const vao = try VertexArray.init(mesh.vertices, mesh.indices);
        mesh.deinit();

        try vao.setLayout(material.material.shader.buffer_layout);

        return .{
            .vao = vao,
            .material = material,
            .transform = transform,
        };
    }

    pub fn deinit(self: *Model, allocator: std.mem.Allocator) void {
        self.transform.deinit(allocator);
    }

    pub fn draw(self: *const Model) void {
        self.vao.draw();
    }
};
