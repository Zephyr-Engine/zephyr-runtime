const std = @import("std");
const zimp = @import("zimp");

pub const AssetKind = enum(u8) {
    mesh,
    material,
    texture,
    shader_stage,
    shader_program,
};

pub const Uuid = struct {
    bytes: [16]u8,

    pub const zero: Uuid = .{ .bytes = [_]u8{0} ** 16 };

    pub fn v4(random: std.Random) Uuid {
        var id: Uuid = .{ .bytes = undefined };
        random.bytes(&id.bytes);
        id.bytes[6] = (id.bytes[6] & 0x0f) | 0x40;
        id.bytes[8] = (id.bytes[8] & 0x3f) | 0x80;
        return id;
    }

    pub fn fromBytes(bytes: [16]u8) Uuid {
        return .{ .bytes = bytes };
    }

    pub fn eql(self: Uuid, other: Uuid) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }

    pub fn isZero(self: Uuid) bool {
        return self.eql(zero);
    }

    pub fn toString(self: Uuid) [36]u8 {
        const hex = std.fmt.bytesToHex(self.bytes, .lower);
        var out: [36]u8 = undefined;
        @memcpy(out[0..8], hex[0..8]);
        out[8] = '-';
        @memcpy(out[9..13], hex[8..12]);
        out[13] = '-';
        @memcpy(out[14..18], hex[12..16]);
        out[18] = '-';
        @memcpy(out[19..23], hex[16..20]);
        out[23] = '-';
        @memcpy(out[24..36], hex[20..32]);
        return out;
    }
};

pub const AssetId = Uuid;

pub const AssetRef = struct {
    kind: AssetKind,
    id: AssetId,
};

pub fn inferKind(path: []const u8) ?AssetKind {
    return switch (zimp.runtime.detectType(path) orelse return null) {
        .mesh => .mesh,
        .material => .material,
        .texture => .texture,
        .shader => .shader_stage,
    };
}

const testing = std.testing;

test "inferKind maps supported cooked extensions" {
    try testing.expectEqual(AssetKind.mesh, inferKind("monkey.zmesh").?);
    try testing.expectEqual(AssetKind.material, inferKind("monkey.zamat").?);
    try testing.expectEqual(AssetKind.texture, inferKind("brick_albedo.ztex").?);
    try testing.expectEqual(AssetKind.shader_stage, inferKind("basic.vert.zshdr").?);
}

test "inferKind requires lowercase cooked extensions" {
    try testing.expect(inferKind("MONKEY.ZMESH") == null);
}

test "Uuid.v4 sets RFC 4122 version and variant bits" {
    var prng = std.Random.DefaultPrng.init(0);
    const id = Uuid.v4(prng.random());
    try testing.expectEqual(@as(u8, 0x40), id.bytes[6] & 0xf0);
    try testing.expectEqual(@as(u8, 0x80), id.bytes[8] & 0xc0);
    try testing.expect(!id.isZero());
}

test "Uuid.toString formats canonical lowercase UUID text" {
    const id = Uuid.fromBytes(.{
        0x12, 0x34, 0x56, 0x78,
        0x9a, 0xbc, 0x4d, 0xef,
        0x80, 0x12, 0x34, 0x56,
        0x78, 0x9a, 0xbc, 0xde,
    });
    try testing.expectEqualStrings("12345678-9abc-4def-8012-3456789abcde", &id.toString());
}

test "Uuid equality and zero detection use all bytes" {
    const zero = Uuid.zero;
    const same_zero = Uuid.fromBytes([_]u8{0} ** 16);
    var non_zero_bytes = [_]u8{0} ** 16;
    non_zero_bytes[15] = 1;
    const non_zero = Uuid.fromBytes(non_zero_bytes);

    try testing.expect(zero.eql(same_zero));
    try testing.expect(zero.isZero());
    try testing.expect(!zero.eql(non_zero));
    try testing.expect(!non_zero.isZero());
}
