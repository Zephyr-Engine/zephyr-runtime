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

pub fn parse(allocator: Allocator, gltf_json: []const u8, bin_data: []const u8) !GltfResult {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, gltf_json, .{});
    defer parsed.deinit();

    const root = parsed.value.object;

    const accessors = (root.get("accessors") orelse return GltfError.InvalidGltf).array.items;
    const buffer_views = (root.get("bufferViews") orelse return GltfError.InvalidGltf).array.items;
    const meshes_json = (root.get("meshes") orelse return GltfError.InvalidGltf).array.items;
    const nodes = (root.get("nodes") orelse return GltfError.InvalidGltf).array.items;

    // Build mesh-index → world transform mapping by walking the node tree
    const mesh_transforms = try allocator.alloc(Mat4, meshes_json.len);
    defer allocator.free(mesh_transforms);
    for (mesh_transforms) |*m| {
        m.* = identity();
    }

    // Walk all nodes recursively from scene roots
    const scenes = root.get("scenes");
    if (scenes) |s| {
        for (s.array.items) |scene| {
            if (scene.object.get("nodes")) |scene_nodes| {
                for (scene_nodes.array.items) |node_idx_val| {
                    const node_idx: usize = @intCast(jsonInt(node_idx_val));
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

    // First pass: count totals
    var total_vertices: usize = 0;
    var total_indices: usize = 0;

    for (meshes_json) |mesh_val| {
        const primitives = mesh_val.object.get("primitives") orelse continue;
        for (primitives.array.items) |prim| {
            const attrs = prim.object.get("attributes") orelse continue;
            const pos_accessor_idx = jsonInt(attrs.object.get("POSITION") orelse continue);
            const pos_accessor = accessors[@intCast(pos_accessor_idx)];
            const vert_count: usize = @intCast(jsonInt(pos_accessor.object.get("count") orelse continue));
            total_vertices += vert_count;

            const idx_accessor_idx = jsonInt(prim.object.get("indices") orelse continue);
            const idx_accessor = accessors[@intCast(idx_accessor_idx)];
            const idx_count: usize = @intCast(jsonInt(idx_accessor.object.get("count") orelse continue));
            total_indices += idx_count;
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
    for (meshes_json, 0..) |mesh_val, mesh_idx| {
        const world = mesh_transforms[mesh_idx];

        const primitives = mesh_val.object.get("primitives") orelse continue;
        for (primitives.array.items) |prim| {
            const attrs = prim.object.get("attributes") orelse continue;

            const pos_acc_idx: usize = @intCast(jsonInt(attrs.object.get("POSITION") orelse continue));
            const pos_accessor = accessors[pos_acc_idx].object;
            const vert_count: usize = @intCast(jsonInt(pos_accessor.get("count").?));

            const pos_data = getAccessorData(pos_accessor, buffer_views);
            const pos_stride = getStride(pos_accessor, buffer_views, 12);

            var norm_data: ?AccessorData = null;
            var norm_stride: usize = 12;
            if (attrs.object.get("NORMAL")) |norm_val| {
                const norm_acc_idx: usize = @intCast(jsonInt(norm_val));
                const norm_accessor = accessors[norm_acc_idx].object;
                norm_data = getAccessorData(norm_accessor, buffer_views);
                norm_stride = getStride(norm_accessor, buffer_views, 12);
            }

            var tc_data: ?AccessorData = null;
            var tc_stride: usize = 8;
            if (attrs.object.get("TEXCOORD_0")) |tc_val| {
                const tc_acc_idx: usize = @intCast(jsonInt(tc_val));
                const tc_accessor = accessors[tc_acc_idx].object;
                tc_data = getAccessorData(tc_accessor, buffer_views);
                tc_stride = getStride(tc_accessor, buffer_views, 8);
            }

            for (0..vert_count) |vi| {
                const out_base = (vert_offset + vi) * 8;

                // Position - transform by world matrix
                const p_off = pos_data.offset + vi * pos_stride;
                const px: f32 = @bitCast(bin_data[p_off..][0..4].*);
                const py: f32 = @bitCast(bin_data[p_off + 4 ..][0..4].*);
                const pz: f32 = @bitCast(bin_data[p_off + 8 ..][0..4].*);
                const tp = mulPoint(world, px, py, pz);
                vertices[out_base + 0] = tp[0];
                vertices[out_base + 1] = tp[1];
                vertices[out_base + 2] = tp[2];

                // Normal - transform by normal matrix (inverse transpose of upper-left 3x3)
                if (norm_data) |nd| {
                    const n_off = nd.offset + vi * norm_stride;
                    const nx: f32 = @bitCast(bin_data[n_off..][0..4].*);
                    const ny: f32 = @bitCast(bin_data[n_off + 4 ..][0..4].*);
                    const nz: f32 = @bitCast(bin_data[n_off + 8 ..][0..4].*);
                    const tn = mulDir(world, nx, ny, nz);
                    // Normalize
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
                if (tc_data) |td| {
                    const t_off = td.offset + vi * tc_stride;
                    vertices[out_base + 6] = @bitCast(bin_data[t_off..][0..4].*);
                    vertices[out_base + 7] = @bitCast(bin_data[t_off + 4 ..][0..4].*);
                } else {
                    vertices[out_base + 6] = 0.0;
                    vertices[out_base + 7] = 0.0;
                }
            }

            // Read indices
            const idx_acc_idx: usize = @intCast(jsonInt(prim.object.get("indices").?));
            const idx_accessor = accessors[idx_acc_idx].object;
            const idx_count: usize = @intCast(jsonInt(idx_accessor.get("count").?));
            const component_type: usize = @intCast(jsonInt(idx_accessor.get("componentType").?));
            const idx_data = getAccessorData(idx_accessor, buffer_views);

            for (0..idx_count) |ii| {
                const raw_index: u32 = switch (component_type) {
                    5125 => blk: {
                        const off = idx_data.offset + ii * 4;
                        break :blk @bitCast(bin_data[off..][0..4].*);
                    },
                    5123 => blk: {
                        const off = idx_data.offset + ii * 2;
                        const val: u16 = @bitCast(bin_data[off..][0..2].*);
                        break :blk @as(u32, val);
                    },
                    5121 => blk: {
                        const off = idx_data.offset + ii;
                        break :blk @as(u32, bin_data[off]);
                    },
                    else => return GltfError.UnsupportedComponentType,
                };
                indices[idx_offset + ii] = raw_index + base_vertex;
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

fn walkNode(nodes: []const std.json.Value, node_idx: usize, parent_transform: Mat4, mesh_transforms: []Mat4) void {
    if (node_idx >= nodes.len) return;
    const node = nodes[node_idx].object;

    const local = getNodeMatrix(node);
    const world = mulMat(parent_transform, local);

    // If this node has a mesh, store its world transform
    if (node.get("mesh")) |mesh_val| {
        const mesh_idx: usize = @intCast(jsonInt(mesh_val));
        if (mesh_idx < mesh_transforms.len) {
            mesh_transforms[mesh_idx] = world;
        }
    }

    // Recurse into children
    if (node.get("children")) |children| {
        for (children.array.items) |child_val| {
            const child_idx: usize = @intCast(jsonInt(child_val));
            walkNode(nodes, child_idx, world, mesh_transforms);
        }
    }
}

fn getNodeMatrix(node: std.json.ObjectMap) Mat4 {
    if (node.get("matrix")) |mat_val| {
        const items = mat_val.array.items;
        if (items.len == 16) {
            // GLTF stores matrices in column-major order
            var m: Mat4 = undefined;
            for (0..4) |col| {
                for (0..4) |row| {
                    m[col][row] = jsonFloat(items[col * 4 + row]);
                }
            }
            return m;
        }
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

const AccessorData = struct {
    offset: usize,
};

fn getAccessorData(accessor: std.json.ObjectMap, buffer_views: []const std.json.Value) AccessorData {
    const bv_idx: usize = @intCast(jsonInt(accessor.get("bufferView").?));
    const bv = buffer_views[bv_idx].object;

    const bv_offset: usize = if (bv.get("byteOffset")) |v| @intCast(jsonInt(v)) else 0;
    const acc_offset: usize = if (accessor.get("byteOffset")) |v| @intCast(jsonInt(v)) else 0;

    return .{ .offset = bv_offset + acc_offset };
}

fn getStride(accessor: std.json.ObjectMap, buffer_views: []const std.json.Value, default_stride: usize) usize {
    const bv_idx: usize = @intCast(jsonInt(accessor.get("bufferView").?));
    const bv = buffer_views[bv_idx].object;
    if (bv.get("byteStride")) |v| {
        return @intCast(jsonInt(v));
    }
    return default_stride;
}

fn jsonInt(val: std.json.Value) i64 {
    return switch (val) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => 0,
    };
}

fn jsonFloat(val: std.json.Value) f32 {
    return switch (val) {
        .float => |f| @floatCast(f),
        .integer => |i| @floatFromInt(i),
        else => 0,
    };
}
