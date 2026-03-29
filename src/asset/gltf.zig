const std = @import("std");
const Allocator = std.mem.Allocator;
const obj = @import("object.zig");

pub const GltfError = error{
    InvalidGltf,
    MissingBuffer,
    UnsupportedComponentType,
    OutOfMemory,
    Overflow,
};

pub const GltfResult = struct {
    mesh: obj.Mesh,
};

const Mat4 = [4][4]f32;

// --- Typed GLTF JSON structures (avoids dynamic Value tree) ---

const GltfFile = struct {
    accessors: []const Accessor = &.{},
    bufferViews: []const BufferView = &.{},
    meshes: []const GltfMesh = &.{},
    nodes: []const Node = &.{},
    scenes: []const Scene = &.{},
};

const Accessor = struct {
    bufferView: ?usize = null,
    byteOffset: usize = 0,
    componentType: usize = 0,
    count: usize = 0,
};

const BufferView = struct {
    byteOffset: usize = 0,
    byteLength: usize = 0,
    byteStride: ?usize = null,
};

const Attributes = struct {
    POSITION: ?usize = null,
    NORMAL: ?usize = null,
    TEXCOORD_0: ?usize = null,
};

const Primitive = struct {
    attributes: Attributes = .{},
    indices: ?usize = null,
};

const GltfMesh = struct {
    primitives: []const Primitive = &.{},
};

const Node = struct {
    mesh: ?usize = null,
    matrix: ?[16]f64 = null,
    children: ?[]const usize = null,
};

const Scene = struct {
    nodes: ?[]const usize = null,
};

pub fn parse(allocator: Allocator, gltf_json: []const u8, bin_data: []const u8) !GltfResult {
    const parsed = try std.json.parseFromSlice(GltfFile, allocator, gltf_json, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    const file = parsed.value;
    const accessors = file.accessors;
    const buffer_views = file.bufferViews;
    const meshes = file.meshes;
    const nodes = file.nodes;

    // Build mesh-index → world transform mapping by walking the node tree
    const mesh_transforms = try allocator.alloc(Mat4, meshes.len);
    defer allocator.free(mesh_transforms);
    for (mesh_transforms) |*m| {
        m.* = identity();
    }

    // Walk all nodes recursively from scene roots
    if (file.scenes.len > 0) {
        for (file.scenes) |scene| {
            if (scene.nodes) |scene_nodes| {
                for (scene_nodes) |node_idx| {
                    walkNode(nodes, node_idx, identity(), mesh_transforms);
                }
            }
        }
    } else {
        // No scenes, walk all nodes that might have meshes
        for (nodes, 0..) |_, i| {
            walkNode(nodes, i, identity(), mesh_transforms);
        }
    }

    // First pass: count totals (cheap with typed structs - direct field access)
    var total_vertices: usize = 0;
    var total_indices: usize = 0;

    for (meshes) |mesh| {
        for (mesh.primitives) |prim| {
            const pos_idx = prim.attributes.POSITION orelse continue;
            total_vertices += accessors[pos_idx].count;
            const idx_idx = prim.indices orelse continue;
            total_indices += accessors[idx_idx].count;
        }
    }

    // Allocate output buffers
    var vertices = try allocator.alloc(f32, total_vertices * 8);
    errdefer allocator.free(vertices);
    var indices = try allocator.alloc(u32, total_indices);
    errdefer allocator.free(indices);

    var vert_offset: usize = 0;
    var idx_offset: usize = 0;
    var base_vertex: u32 = 0;

    // Second pass: extract data with transforms applied
    for (meshes, 0..) |mesh, mesh_idx| {
        const world = mesh_transforms[mesh_idx];

        for (mesh.primitives) |prim| {
            const pos_acc_idx = prim.attributes.POSITION orelse continue;
            const pos_acc = accessors[pos_acc_idx];
            const vert_count = pos_acc.count;

            const pos_offset = getOffset(pos_acc, buffer_views);
            const pos_stride = getStride(pos_acc, buffer_views, 12);

            // Resolve optional attributes once per primitive, not per vertex
            const has_normals = prim.attributes.NORMAL != null;
            const norm_offset = if (prim.attributes.NORMAL) |ni| getOffset(accessors[ni], buffer_views) else 0;
            const norm_stride = if (prim.attributes.NORMAL) |ni| getStride(accessors[ni], buffer_views, 12) else 0;

            const has_texcoords = prim.attributes.TEXCOORD_0 != null;
            const tc_offset = if (prim.attributes.TEXCOORD_0) |ti| getOffset(accessors[ti], buffer_views) else 0;
            const tc_stride = if (prim.attributes.TEXCOORD_0) |ti| getStride(accessors[ti], buffer_views, 8) else 0;

            for (0..vert_count) |vi| {
                const out_base = (vert_offset + vi) * 8;

                // Position - batch read 3 floats, transform by world matrix
                const p_off = pos_offset + vi * pos_stride;
                const pos = std.mem.bytesToValue([3]f32, bin_data[p_off..][0..12]);
                const tp = mulPoint(world, pos[0], pos[1], pos[2]);
                vertices[out_base + 0] = tp[0];
                vertices[out_base + 1] = tp[1];
                vertices[out_base + 2] = tp[2];

                // Normal - transform by upper-left 3x3 and normalize
                if (has_normals) {
                    const n_off = norm_offset + vi * norm_stride;
                    const norm = std.mem.bytesToValue([3]f32, bin_data[n_off..][0..12]);
                    const tn = mulDir(world, norm[0], norm[1], norm[2]);
                    const len = @sqrt(tn[0] * tn[0] + tn[1] * tn[1] + tn[2] * tn[2]);
                    if (len > 1e-8) {
                        vertices[out_base + 3] = tn[0] / len;
                        vertices[out_base + 4] = tn[1] / len;
                        vertices[out_base + 5] = tn[2] / len;
                    } else {
                        vertices[out_base + 3] = 0.0;
                        vertices[out_base + 4] = 1.0;
                        vertices[out_base + 5] = 0.0;
                    }
                } else {
                    vertices[out_base + 3] = 0.0;
                    vertices[out_base + 4] = 1.0;
                    vertices[out_base + 5] = 0.0;
                }

                // Texcoord - pass through unchanged
                if (has_texcoords) {
                    const t_off = tc_offset + vi * tc_stride;
                    const tc = std.mem.bytesToValue([2]f32, bin_data[t_off..][0..8]);
                    vertices[out_base + 6] = tc[0];
                    vertices[out_base + 7] = tc[1];
                } else {
                    vertices[out_base + 6] = 0.0;
                    vertices[out_base + 7] = 0.0;
                }
            }

            // Read indices - switch on component type OUTSIDE the loop
            const idx_acc_idx = prim.indices orelse continue;
            const idx_acc = accessors[idx_acc_idx];
            const idx_count = idx_acc.count;
            const idx_data_offset = getOffset(idx_acc, buffer_views);

            switch (idx_acc.componentType) {
                5125 => { // GL_UNSIGNED_INT
                    for (0..idx_count) |ii| {
                        const off = idx_data_offset + ii * 4;
                        indices[idx_offset + ii] = std.mem.bytesToValue(u32, bin_data[off..][0..4]) + base_vertex;
                    }
                },
                5123 => { // GL_UNSIGNED_SHORT
                    for (0..idx_count) |ii| {
                        const off = idx_data_offset + ii * 2;
                        indices[idx_offset + ii] = @as(u32, std.mem.bytesToValue(u16, bin_data[off..][0..2])) + base_vertex;
                    }
                },
                5121 => { // GL_UNSIGNED_BYTE
                    for (0..idx_count) |ii| {
                        indices[idx_offset + ii] = @as(u32, bin_data[idx_data_offset + ii]) + base_vertex;
                    }
                },
                else => return GltfError.UnsupportedComponentType,
            }

            vert_offset += vert_count;
            idx_offset += idx_count;
            base_vertex += @intCast(vert_count);
        }
    }

    return .{
        .mesh = .{
            .vertices = vertices,
            .indices = indices,
            .allocator = allocator,
        },
    };
}

// --- Node tree walking ---

fn walkNode(nodes: []const Node, node_idx: usize, parent_transform: Mat4, mesh_transforms: []Mat4) void {
    if (node_idx >= nodes.len) return;
    const node = nodes[node_idx];

    const local = getNodeMatrix(node);
    const world = mulMat(parent_transform, local);

    if (node.mesh) |mesh_idx| {
        if (mesh_idx < mesh_transforms.len) {
            mesh_transforms[mesh_idx] = world;
        }
    }

    if (node.children) |children| {
        for (children) |child_idx| {
            walkNode(nodes, child_idx, world, mesh_transforms);
        }
    }
}

fn getNodeMatrix(node: Node) Mat4 {
    if (node.matrix) |mat| {
        var m: Mat4 = undefined;
        for (0..4) |col| {
            for (0..4) |row| {
                m[col][row] = @floatCast(mat[col * 4 + row]);
            }
        }
        return m;
    }
    return identity();
}

// --- Matrix math ---

fn identity() Mat4 {
    return .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
}

fn mulMat(a: Mat4, b: Mat4) Mat4 {
    var result: Mat4 = undefined;
    for (0..4) |col| {
        for (0..4) |row| {
            var sum: f32 = 0;
            for (0..4) |k| {
                sum += a[k][row] * b[col][k];
            }
            result[col][row] = sum;
        }
    }
    return result;
}

fn mulPoint(m: Mat4, x: f32, y: f32, z: f32) [3]f32 {
    return .{
        m[0][0] * x + m[1][0] * y + m[2][0] * z + m[3][0],
        m[0][1] * x + m[1][1] * y + m[2][1] * z + m[3][1],
        m[0][2] * x + m[1][2] * y + m[2][2] * z + m[3][2],
    };
}

fn mulDir(m: Mat4, x: f32, y: f32, z: f32) [3]f32 {
    return .{
        m[0][0] * x + m[1][0] * y + m[2][0] * z,
        m[0][1] * x + m[1][1] * y + m[2][1] * z,
        m[0][2] * x + m[1][2] * y + m[2][2] * z,
    };
}

// --- Accessor helpers ---

fn getOffset(accessor: Accessor, buffer_views: []const BufferView) usize {
    const bv = buffer_views[accessor.bufferView orelse 0];
    return bv.byteOffset + accessor.byteOffset;
}

fn getStride(accessor: Accessor, buffer_views: []const BufferView, default: usize) usize {
    const bv = buffer_views[accessor.bufferView orelse 0];
    return bv.byteStride orelse default;
}
