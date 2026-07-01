const std = @import("std");
const zimp = @import("zimp");

pub const ParseError = error{
    InvalidUuid,
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

    pub fn parse(text: []const u8) ParseError!Uuid {
        if (text.len != 36) {
            return ParseError.InvalidUuid;
        }

        if (text[8] != '-' or text[13] != '-' or text[18] != '-' or text[23] != '-') {
            return ParseError.InvalidUuid;
        }

        var out: [16]u8 = undefined;
        var out_i: usize = 0;
        var i: usize = 0;
        while (i < text.len) {
            if (text[i] == '-') {
                i += 1;
                continue;
            }
            if (i + 1 >= text.len) {
                return error.InvalidUuid;
            }
            const hi = try hexNibble(text[i]);
            const lo = try hexNibble(text[i + 1]);
            out[out_i] = (hi << 4) | lo;
            out_i += 1;
            i += 2;
        }
        if (out_i != 16) {
            return error.InvalidUuid;
        }
        return .{ .bytes = out };
    }
};

fn hexNibble(c: u8) ParseError!u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        else => error.InvalidUuid,
    };
}

const testing = std.testing;

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
