const std = @import("std");

pub const PathError = error{
    AbsolutePathNotAllowed,
    ParentTraversalNotAllowed,
    EmptyPath,
    UnsupportedExtension,
    PathTooLong,
    OutOfMemory,
};

pub const max_virtual_path_len: usize = 4096;

pub fn normalizeVirtualPath(allocator: std.mem.Allocator, raw_path: []const u8) PathError![]u8 {
    if (raw_path.len == 0) {
        return PathError.EmptyPath;
    }
    if (raw_path.len > max_virtual_path_len) {
        return PathError.PathTooLong;
    }
    if (isAbsolutePath(raw_path)) {
        return PathError.AbsolutePathNotAllowed;
    }

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < raw_path.len) {
        while (i < raw_path.len and isSeparator(raw_path[i])) : (i += 1) {}
        const start = i;
        while (i < raw_path.len and !isSeparator(raw_path[i])) : (i += 1) {}
        const segment = raw_path[start..i];

        if (segment.len == 0 or std.mem.eql(u8, segment, ".")) {
            continue;
        }
        if (std.mem.eql(u8, segment, "..")) {
            return PathError.ParentTraversalNotAllowed;
        }

        if (out.items.len != 0) {
            try out.append(allocator, '/');
        }
        try out.appendSlice(allocator, segment);
    }

    if (out.items.len == 0) {
        return PathError.EmptyPath;
    }
    if (out.items.len > max_virtual_path_len) {
        return PathError.PathTooLong;
    }

    return out.toOwnedSlice(allocator);
}

pub fn validateVirtualPath(path: []const u8) PathError!void {
    if (path.len == 0) {
        return PathError.EmptyPath;
    }
    if (path.len > max_virtual_path_len) {
        return PathError.PathTooLong;
    }
    if (isAbsolutePath(path)) {
        return PathError.AbsolutePathNotAllowed;
    }

    var saw_segment = false;
    var i: usize = 0;
    while (i < path.len) {
        while (i < path.len and isSeparator(path[i])) : (i += 1) {}
        const start = i;
        while (i < path.len and !isSeparator(path[i])) : (i += 1) {}
        const segment = path[start..i];
        if (segment.len == 0 or std.mem.eql(u8, segment, ".")) {
            continue;
        }
        if (std.mem.eql(u8, segment, "..")) {
            return PathError.ParentTraversalNotAllowed;
        }
        saw_segment = true;
    }

    if (!saw_segment) {
        return PathError.EmptyPath;
    }
}

pub fn resolveMaterialRelative(
    allocator: std.mem.Allocator,
    material_path: []const u8,
    dependency_path: []const u8,
) PathError![]u8 {
    try validateVirtualPath(material_path);
    if (dependency_path.len == 0) return PathError.EmptyPath;
    if (isAbsolutePath(dependency_path)) return PathError.AbsolutePathNotAllowed;

    const slash_index = std.mem.lastIndexOfScalar(u8, material_path, '/');
    if (slash_index == null) {
        return normalizeVirtualPath(allocator, dependency_path);
    }

    const material_dir = material_path[0..slash_index.?];
    const joined = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ material_dir, dependency_path });
    defer allocator.free(joined);

    return normalizeVirtualPath(allocator, joined);
}

fn isSeparator(byte: u8) bool {
    return byte == '/' or byte == '\\';
}

fn isAbsolutePath(path: []const u8) bool {
    if (path.len == 0) {
        return false;
    }
    if (isSeparator(path[0])) {
        return true;
    }
    return path.len >= 2 and std.ascii.isAlphabetic(path[0]) and path[1] == ':';
}

const testing = std.testing;

fn expectNormalized(input: []const u8, expected: []const u8) !void {
    const normalized = try normalizeVirtualPath(testing.allocator, input);
    defer testing.allocator.free(normalized);
    try testing.expectEqualStrings(expected, normalized);
}

test "normalizeVirtualPath normalizes separators and leading dot segments" {
    try expectNormalized("meshes\\monkey.zmesh", "meshes/monkey.zmesh");
    try expectNormalized("./monkey.zmesh", "monkey.zmesh");
    try expectNormalized("meshes///monkey.zmesh", "meshes/monkey.zmesh");
}

test "normalizeVirtualPath rejects unsafe paths" {
    try testing.expectError(PathError.ParentTraversalNotAllowed, normalizeVirtualPath(testing.allocator, "../secret.zmesh"));
    try testing.expectError(PathError.ParentTraversalNotAllowed, normalizeVirtualPath(testing.allocator, "materials/../secret.zmesh"));
    try testing.expectError(PathError.AbsolutePathNotAllowed, normalizeVirtualPath(testing.allocator, "/tmp/file.zmesh"));
    try testing.expectError(PathError.AbsolutePathNotAllowed, normalizeVirtualPath(testing.allocator, "C:\\tmp\\file.zmesh"));
}

test "resolveMaterialRelative joins sibling dependencies" {
    const resolved = try resolveMaterialRelative(testing.allocator, "materials/monkey.zamat", "brick_albedo.ztex");
    defer testing.allocator.free(resolved);
    try testing.expectEqualStrings("materials/brick_albedo.ztex", resolved);
}

test "resolveMaterialRelative rejects parent traversal" {
    try testing.expectError(
        PathError.ParentTraversalNotAllowed,
        resolveMaterialRelative(testing.allocator, "materials/monkey.zamat", "../x.ztex"),
    );
}
