const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Mesh = struct {
    vertices: []f32,
    indices: []u32,
    allocator: Allocator,

    pub fn deinit(self: *Mesh) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
    }
};

pub fn parse(allocator: Allocator, data: []const u8) !Mesh {
    var parser = Parser.init(allocator);
    defer parser.deinit();

    return try parser.parse(data);
}

const VertexKey = struct {
    pos_idx: u32,
    norm_idx: u32,
    tex_idx: u32,
};

const Parser = struct {
    allocator: Allocator,

    positions: std.ArrayList(f32),
    normals: std.ArrayList(f32),
    texcoords: std.ArrayList(f32),

    vertices: std.ArrayList(f32),
    indices: std.ArrayList(u32),

    vertex_map: std.AutoHashMap(VertexKey, u32),
    face_indices: std.ArrayList(VertexKey),

    fn init(allocator: Allocator) Parser {
        return .{
            .allocator = allocator,
            .positions = .empty,
            .normals = .empty,
            .texcoords = .empty,
            .vertices = .empty,
            .indices = .empty,
            .vertex_map = std.AutoHashMap(VertexKey, u32).init(allocator),
            .face_indices = .empty,
        };
    }

    fn deinit(self: *Parser) void {
        self.positions.deinit(self.allocator);
        self.normals.deinit(self.allocator);
        self.texcoords.deinit(self.allocator);
        self.vertices.deinit(self.allocator);
        self.indices.deinit(self.allocator);
        self.vertex_map.deinit();
        self.face_indices.deinit(self.allocator);
    }

    fn parse(self: *Parser, data: []const u8) !Mesh {
        var lines = std.mem.splitScalar(u8, data, '\n');

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0) continue;

            var tokens = std.mem.tokenizeAny(u8, trimmed, " ");
            const cmd = tokens.next() orelse continue;

            if (std.mem.eql(u8, cmd, "v")) {
                try self.parsePosition(&tokens);
            } else if (std.mem.eql(u8, cmd, "vn")) {
                try self.parseNormal(&tokens);
            } else if (std.mem.eql(u8, cmd, "vt")) {
                try self.parseTexCoord(&tokens);
            } else if (std.mem.eql(u8, cmd, "f")) {
                try self.parseFace(&tokens);
            }
        }

        return Mesh{
            .vertices = try self.vertices.toOwnedSlice(self.allocator),
            .indices = try self.indices.toOwnedSlice(self.allocator),
            .allocator = self.allocator,
        };
    }

    fn parsePosition(self: *Parser, tokens: *std.mem.TokenIterator(u8, .any)) !void {
        const x = try std.fmt.parseFloat(f32, tokens.next() orelse return error.InvalidVertex);
        const y = try std.fmt.parseFloat(f32, tokens.next() orelse return error.InvalidVertex);
        const z = try std.fmt.parseFloat(f32, tokens.next() orelse return error.InvalidVertex);

        try self.positions.append(self.allocator, x);
        try self.positions.append(self.allocator, y);
        try self.positions.append(self.allocator, z);
    }

    fn parseNormal(self: *Parser, tokens: *std.mem.TokenIterator(u8, .any)) !void {
        const x = try std.fmt.parseFloat(f32, tokens.next() orelse return error.InvalidNormal);
        const y = try std.fmt.parseFloat(f32, tokens.next() orelse return error.InvalidNormal);
        const z = try std.fmt.parseFloat(f32, tokens.next() orelse return error.InvalidNormal);

        try self.normals.append(self.allocator, x);
        try self.normals.append(self.allocator, y);
        try self.normals.append(self.allocator, z);
    }

    fn parseTexCoord(self: *Parser, tokens: *std.mem.TokenIterator(u8, .any)) !void {
        const u = try std.fmt.parseFloat(f32, tokens.next() orelse return error.InvalidTexCoord);
        const v = try std.fmt.parseFloat(f32, tokens.next() orelse return error.InvalidTexCoord);

        try self.texcoords.append(self.allocator, u);
        try self.texcoords.append(self.allocator, v);
    }

    fn parseFace(self: *Parser, tokens: *std.mem.TokenIterator(u8, .any)) !void {
        self.face_indices.clearRetainingCapacity();

        while (tokens.next()) |vertex_str| {
            const key = try self.parseVertexIndices(vertex_str);
            try self.face_indices.append(self.allocator, key);
        }

        const num_vertices = self.face_indices.items.len;
        if (num_vertices < 3) return error.InvalidFace;

        for (1..num_vertices - 1) |i| {
            try self.emitTriangle(
                self.face_indices.items[0],
                self.face_indices.items[i],
                self.face_indices.items[i + 1],
            );
        }
    }

    fn parseVertexIndices(self: *Parser, vertex_str: []const u8) !VertexKey {
        var indices = std.mem.splitScalar(u8, vertex_str, '/');

        const pos_str = indices.next() orelse return error.InvalidFaceVertex;
        const pos_idx = try parseIndex(pos_str, self.positions.items.len / 3);

        const tex_str = indices.next() orelse "";
        const tex_idx = if (tex_str.len > 0)
            (try parseIndex(tex_str, self.texcoords.items.len / 2)) + 1
        else
            0;

        const norm_str = indices.next() orelse "";
        const norm_idx = if (norm_str.len > 0)
            (try parseIndex(norm_str, self.normals.items.len / 3)) + 1
        else
            0;

        return VertexKey{
            .pos_idx = pos_idx,
            .norm_idx = norm_idx,
            .tex_idx = tex_idx,
        };
    }

    fn emitTriangle(self: *Parser, v0: VertexKey, v1: VertexKey, v2: VertexKey) !void {
        try self.indices.append(self.allocator, try self.getOrCreateVertex(v0));
        try self.indices.append(self.allocator, try self.getOrCreateVertex(v1));
        try self.indices.append(self.allocator, try self.getOrCreateVertex(v2));
    }

    fn getOrCreateVertex(self: *Parser, key: VertexKey) !u32 {
        const result = try self.vertex_map.getOrPut(key);
        if (!result.found_existing) {
            const vertex_idx = self.vertex_map.count() - 1;
            result.value_ptr.* = @intCast(vertex_idx);

            const pos_base = key.pos_idx * 3;
            try self.vertices.append(self.allocator, self.positions.items[pos_base]);
            try self.vertices.append(self.allocator, self.positions.items[pos_base + 1]);
            try self.vertices.append(self.allocator, self.positions.items[pos_base + 2]);

            if (key.norm_idx > 0 and self.normals.items.len > 0) {
                const norm_base = (key.norm_idx - 1) * 3;
                try self.vertices.append(self.allocator, self.normals.items[norm_base]);
                try self.vertices.append(self.allocator, self.normals.items[norm_base + 1]);
                try self.vertices.append(self.allocator, self.normals.items[norm_base + 2]);
            } else {
                try self.vertices.append(self.allocator, 0.0);
                try self.vertices.append(self.allocator, 1.0);
                try self.vertices.append(self.allocator, 0.0);
            }

            if (key.tex_idx > 0 and self.texcoords.items.len > 0) {
                const tex_base = (key.tex_idx - 1) * 2;
                try self.vertices.append(self.allocator, self.texcoords.items[tex_base]);
                try self.vertices.append(self.allocator, self.texcoords.items[tex_base + 1]);
            } else {
                try self.vertices.append(self.allocator, 0.0);
                try self.vertices.append(self.allocator, 0.0);
            }
        }

        return result.value_ptr.*;
    }
};

fn parseIndex(str: []const u8, count: usize) !u32 {
    const idx = try std.fmt.parseInt(i32, str, 10);

    if (idx < 0) {
        return @intCast(@as(i32, @intCast(count)) + idx);
    } else if (idx > 0) {
        return @intCast(idx - 1);
    } else {
        return error.InvalidIndex;
    }
}

const testing = std.testing;

test "parse simple triangle" {
    const data =
        \\v 0.0 0.0 0.0
        \\v 1.0 0.0 0.0
        \\v 0.0 1.0 0.0
        \\f 1 2 3
    ;

    var mesh = try parse(testing.allocator, data);
    defer mesh.deinit();

    // Should have 3 vertices (8 floats each = 24 total)
    try testing.expectEqual(24, mesh.vertices.len);
    try testing.expectEqual(3, mesh.indices.len);

    // Check first vertex position
    try testing.expectEqual(0.0, mesh.vertices[0]);
    try testing.expectEqual(0.0, mesh.vertices[1]);
    try testing.expectEqual(0.0, mesh.vertices[2]);

    // Check indices
    try testing.expectEqual(0, mesh.indices[0]);
    try testing.expectEqual(1, mesh.indices[1]);
    try testing.expectEqual(2, mesh.indices[2]);
}

test "parse quad - should triangulate" {
    const data =
        \\v 0.0 0.0 0.0
        \\v 1.0 0.0 0.0
        \\v 1.0 1.0 0.0
        \\v 0.0 1.0 0.0
        \\f 1 2 3 4
    ;

    var mesh = try parse(testing.allocator, data);
    defer mesh.deinit();

    // Should have 4 unique vertices
    try testing.expectEqual(32, mesh.vertices.len); // 4 vertices * 8 floats

    // Should have 2 triangles = 6 indices
    try testing.expectEqual(6, mesh.indices.len);

    // First triangle: [0, 1, 2]
    try testing.expectEqual(0, mesh.indices[0]);
    try testing.expectEqual(1, mesh.indices[1]);
    try testing.expectEqual(2, mesh.indices[2]);

    // Second triangle: [0, 2, 3]
    try testing.expectEqual(0, mesh.indices[3]);
    try testing.expectEqual(2, mesh.indices[4]);
    try testing.expectEqual(3, mesh.indices[5]);
}

test "parse with normals and texcoords" {
    const data =
        \\v 0.0 0.0 0.0
        \\v 1.0 0.0 0.0
        \\v 0.0 1.0 0.0
        \\vn 0.0 0.0 1.0
        \\vt 0.0 0.0
        \\vt 1.0 0.0
        \\vt 0.0 1.0
        \\f 1/1/1 2/2/1 3/3/1
    ;

    var mesh = try parse(testing.allocator, data);
    defer mesh.deinit();

    try testing.expectEqual(24, mesh.vertices.len);
    try testing.expectEqual(3, mesh.indices.len);

    // Check first vertex has correct normal
    try testing.expectEqual(0.0, mesh.vertices[3]); // normal.x
    try testing.expectEqual(0.0, mesh.vertices[4]); // normal.y
    try testing.expectEqual(1.0, mesh.vertices[5]); // normal.z

    // Check first vertex has correct texcoord
    try testing.expectEqual(0.0, mesh.vertices[6]); // texcoord.u
    try testing.expectEqual(0.0, mesh.vertices[7]); // texcoord.v
}

test "parse with missing normals - should use defaults" {
    const data =
        \\v 0.0 0.0 0.0
        \\v 1.0 0.0 0.0
        \\v 0.0 1.0 0.0
        \\f 1 2 3
    ;

    var mesh = try parse(testing.allocator, data);
    defer mesh.deinit();

    // Check default normal (0, 1, 0)
    try testing.expectEqual(0.0, mesh.vertices[3]);
    try testing.expectEqual(1.0, mesh.vertices[4]);
    try testing.expectEqual(0.0, mesh.vertices[5]);

    // Check default texcoord (0, 0)
    try testing.expectEqual(0.0, mesh.vertices[6]);
    try testing.expectEqual(0.0, mesh.vertices[7]);
}

test "parse with vertex deduplication" {
    const data =
        \\v 0.0 0.0 0.0
        \\v 1.0 0.0 0.0
        \\vn 0.0 0.0 1.0
        \\vt 0.0 0.0
        \\vt 1.0 0.0
        \\f 1/1/1 2/2/1 1/1/1
    ;

    var mesh = try parse(testing.allocator, data);
    defer mesh.deinit();

    // Should only have 2 unique vertices (vertex 0 is reused)
    try testing.expectEqual(16, mesh.vertices.len); // 2 vertices * 8 floats
    try testing.expectEqual(3, mesh.indices.len);

    // Indices should reuse vertex 0
    try testing.expectEqual(0, mesh.indices[0]);
    try testing.expectEqual(1, mesh.indices[1]);
    try testing.expectEqual(0, mesh.indices[2]);
}

test "parse with negative indices" {
    const data =
        \\v 0.0 0.0 0.0
        \\v 1.0 0.0 0.0
        \\v 0.0 1.0 0.0
        \\f -3 -2 -1
    ;

    var mesh = try parse(testing.allocator, data);
    defer mesh.deinit();

    try testing.expectEqual(24, mesh.vertices.len);
    try testing.expectEqual(3, mesh.indices.len);

    // Should parse correctly (relative indices)
    try testing.expectEqual(0, mesh.indices[0]);
    try testing.expectEqual(1, mesh.indices[1]);
    try testing.expectEqual(2, mesh.indices[2]);
}

test "parse face format v//vn" {
    const data =
        \\v 0.0 0.0 0.0
        \\v 1.0 0.0 0.0
        \\v 0.0 1.0 0.0
        \\vn 0.0 0.0 1.0
        \\f 1//1 2//1 3//1
    ;

    var mesh = try parse(testing.allocator, data);
    defer mesh.deinit();

    try testing.expectEqual(24, mesh.vertices.len);

    // Should have normal but default texcoord
    try testing.expectEqual(0.0, mesh.vertices[3]); // normal.x
    try testing.expectEqual(0.0, mesh.vertices[4]); // normal.y
    try testing.expectEqual(1.0, mesh.vertices[5]); // normal.z
    try testing.expectEqual(0.0, mesh.vertices[6]); // texcoord.u
    try testing.expectEqual(0.0, mesh.vertices[7]); // texcoord.v
}

test "parse multiple faces" {
    const data =
        \\v 0.0 0.0 0.0
        \\v 1.0 0.0 0.0
        \\v 0.0 1.0 0.0
        \\v 1.0 1.0 0.0
        \\f 1 2 3
        \\f 2 4 3
    ;

    var mesh = try parse(testing.allocator, data);
    defer mesh.deinit();

    // Should have 4 unique vertices
    try testing.expectEqual(32, mesh.vertices.len);

    // Should have 2 triangles = 6 indices
    try testing.expectEqual(6, mesh.indices.len);
}

test "parse ignores comments and other commands" {
    const data =
        \\# This is a comment
        \\o Object1
        \\v 0.0 0.0 0.0
        \\v 1.0 0.0 0.0
        \\v 0.0 1.0 0.0
        \\g Group1
        \\usemtl Material1
        \\s 1
        \\f 1 2 3
    ;

    var mesh = try parse(testing.allocator, data);
    defer mesh.deinit();

    // Should parse the triangle correctly, ignoring other commands
    try testing.expectEqual(24, mesh.vertices.len);
    try testing.expectEqual(3, mesh.indices.len);
}

test "parse pentagon - should create 3 triangles" {
    const data =
        \\v 0.0 0.0 0.0
        \\v 1.0 0.0 0.0
        \\v 1.5 1.0 0.0
        \\v 0.5 1.5 0.0
        \\v -0.5 1.0 0.0
        \\f 1 2 3 4 5
    ;

    var mesh = try parse(testing.allocator, data);
    defer mesh.deinit();

    // Should have 5 unique vertices
    try testing.expectEqual(40, mesh.vertices.len); // 5 * 8

    // Pentagon triangulated into 3 triangles = 9 indices
    try testing.expectEqual(9, mesh.indices.len);

    // Triangle 1: [0, 1, 2]
    try testing.expectEqual(0, mesh.indices[0]);
    try testing.expectEqual(1, mesh.indices[1]);
    try testing.expectEqual(2, mesh.indices[2]);

    // Triangle 2: [0, 2, 3]
    try testing.expectEqual(0, mesh.indices[3]);
    try testing.expectEqual(2, mesh.indices[4]);
    try testing.expectEqual(3, mesh.indices[5]);

    // Triangle 3: [0, 3, 4]
    try testing.expectEqual(0, mesh.indices[6]);
    try testing.expectEqual(3, mesh.indices[7]);
    try testing.expectEqual(4, mesh.indices[8]);
}
