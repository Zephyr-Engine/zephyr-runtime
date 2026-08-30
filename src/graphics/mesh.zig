const zimp = @import("zimp");
const std = @import("std");

const Geometry = @import("rhi/geometry.zig");
const Device = @import("rhi/device.zig");
const Buffer = @import("rhi/buffer.zig");
const math = @import("../core/math.zig");
const layout = @import("layout.zig");

pub const AttributeLocation = enum(u32) {
    Position = 0,
    Normal = 1,
    UV0 = 2,
    UV1 = 3,
    Tangent = 4,
    JointIndices = 5,
    JointWeights = 6,
};

const Mesh = @This();
allocator: std.mem.Allocator,
device: *Device,
material_ids: []zimp.AssetId,
parts: []Part,

pub const Part = struct {
    geometry: Geometry,
    buffers: []Buffer,
    transform: math.Mat4,
    bounds_min: [3]f32,
    bounds_max: [3]f32,
    submeshes: []Submesh,
    uv_min: [2]f32,
    uv_scale: [2]f32,

    pub fn deinit(self: *Part, allocator: std.mem.Allocator, device: *Device) void {
        allocator.free(self.submeshes);
        device.destroyGeometry(&self.geometry);

        for (self.buffers) |*buffer| {
            device.destroyBuffer(buffer);
        }
        allocator.free(self.buffers);
    }
};

pub const Submesh = struct { material_index: u16, index_offset: u32, index_count: u32 };

pub fn loadFromZMesh(allocator: std.mem.Allocator, device: *Device, model: *const zimp.ZMesh, material_ids: []zimp.AssetId) !Mesh {
    const parts = try allocator.alloc(Part, model.parts.len);
    errdefer allocator.free(parts);

    var initialized: usize = 0;
    errdefer for (parts[0..initialized]) |*part| part.deinit(allocator, device);
    for (model.parts, parts) |source, *part| {
        part.* = try loadPart(allocator, device, source.mesh, mat4FromArray(source.transform));
        initialized += 1;
    }
    return .{ .allocator = allocator, .device = device, .material_ids = material_ids, .parts = parts };
}

fn loadPart(allocator: std.mem.Allocator, device: *Device, mesh: zimp.formats.zmesh.MeshPart, transform: math.Mat4) !Part {
    var buffers: std.ArrayList(Buffer) = .empty;
    errdefer {
        for (buffers.items) |*b| device.destroyBuffer(b);
        buffers.deinit(allocator);
    }

    var streams: std.ArrayList(Geometry.VertexStream) = .empty;
    defer streams.deinit(allocator);

    try addStream(allocator, device, &buffers, &streams, std.mem.sliceAsBytes(mesh.positions), AttributeLocation.Position, .Float3, false);
    if (mesh.normals) |v| {
        try addStream(allocator, device, &buffers, &streams, std.mem.sliceAsBytes(v), AttributeLocation.Normal, .Short2, true);
    }
    if (mesh.uv0) |v| {
        try addStream(allocator, device, &buffers, &streams, std.mem.sliceAsBytes(v), AttributeLocation.UV0, .UShort2, true);
    }
    if (mesh.uv1) |v| {
        try addStream(allocator, device, &buffers, &streams, std.mem.sliceAsBytes(v), AttributeLocation.UV1, .UShort2, true);
    }
    if (mesh.tangents) |v| {
        try addStream(allocator, device, &buffers, &streams, std.mem.sliceAsBytes(v), AttributeLocation.Tangent, .Half4, false);
    }
    if (mesh.joint_indices) |v| {
        try addStream(allocator, device, &buffers, &streams, std.mem.sliceAsBytes(v), AttributeLocation.JointIndices, .UShort4, false);
    }
    if (mesh.joint_weights) |v| {
        try addStream(allocator, device, &buffers, &streams, std.mem.sliceAsBytes(v), AttributeLocation.JointWeights, .Half4, false);
    }

    const index_bytes: []const u8 = if (mesh.indices_u16) |v| std.mem.sliceAsBytes(v) else if (mesh.indices_u32) |v| std.mem.sliceAsBytes(v) else return error.MissingIndexBuffer;
    const index_format: Geometry.IndexFormat = if (mesh.indices_u16 != null) .u16 else .u32;
    const index_count: u32 = if (mesh.indices_u16) |v| @intCast(v.len) else @intCast(mesh.indices_u32.?.len);
    const index_buffer = try device.createBuffer(.{ .size = index_bytes.len, .usage = .{ .index = true }, .initial_data = index_bytes });

    try buffers.append(allocator, index_buffer);
    const geometry = try device.createGeometry(.{ .streams = streams.items, .index_buffer = index_buffer, .index_format = index_format, .index_count = index_count });
    errdefer {
        var g = geometry;
        device.destroyGeometry(&g);
    }

    const submeshes = try allocator.alloc(Submesh, mesh.submeshes.len);
    errdefer allocator.free(submeshes);
    for (mesh.submeshes, submeshes) |src, *dst| {
        dst.* = .{ .material_index = src.material_index, .index_offset = src.index_offset, .index_count = src.index_count };
    }
    return .{
        .geometry = geometry,
        .buffers = try buffers.toOwnedSlice(allocator),
        .transform = transform,
        .bounds_min = mesh.aabb_min,
        .bounds_max = mesh.aabb_max,
        .uv_min = mesh.uv0_min,
        .uv_scale = mesh.uv0_scale,
        .submeshes = submeshes,
    };
}

fn addStream(
    allocator: std.mem.Allocator,
    device: *Device,
    buffers: *std.ArrayList(Buffer),
    streams: *std.ArrayList(Geometry.VertexStream),
    bytes: []const u8,
    location: AttributeLocation,
    data_type: layout.DataType,
    normalized: bool,
) !void {
    const buffer = try device.createBuffer(.{ .size = bytes.len, .usage = .{ .vertex = true }, .initial_data = bytes });
    var buffer_owned = true;
    errdefer if (buffer_owned) {
        var owned = buffer;
        device.destroyBuffer(&owned);
    };

    try buffers.append(allocator, buffer);
    buffer_owned = false;
    try streams.append(
        allocator,
        .{ .buffer = buffer, .attribute = .{ .location = @intFromEnum(location), .data_type = data_type, .normalized = normalized } },
    );
}

pub fn materialIdForSlot(self: *const Mesh, slot: u16) ?zimp.AssetId {
    const i: usize = @intCast(slot);
    return if (i < self.material_ids.len) self.material_ids[i] else null;
}

pub fn deinit(self: *Mesh) void {
    for (self.parts) |*part| part.deinit(self.allocator, self.device);
    self.allocator.free(self.parts);
    self.allocator.free(self.material_ids);
}

fn mat4FromArray(v: [16]f32) math.Mat4 {
    return .{ .fields = .{ .{ v[0], v[1], v[2], v[3] }, .{ v[4], v[5], v[6], v[7] }, .{ v[8], v[9], v[10], v[11] }, .{ v[12], v[13], v[14], v[15] } } };
}

test "mat4 conversion preserves translation" {
    const m = mat4FromArray(.{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 2, 3, 4, 1 });
    const p = math.Vec3.zero.transformPosition(m);
    try std.testing.expectEqual(@as(f32, 2), p.x);
}
