const std = @import("std");
const zimp = @import("zimp");

pub const AssetError = error{
    InvalidPath,
    UnsupportedAssetKind,
    AssetNotFound,
    WrongAssetKind,
    LoadFailed,
    OutOfMemory,
};

pub const AssetRoots = struct {
    cooked_root: []const u8,
    source_root: ?[]const u8 = null,
};

pub const CookedStore = zimp.runtime.CookedStore;
pub const FileSource = CookedStore;

const testing = std.testing;

test "FileSource opens existing normalized virtual path" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile(testing.io, "asset.zmesh", .{});
    var buf: [32]u8 = undefined;
    var writer = file.writer(testing.io, &buf);
    try writer.interface.writeAll("asset bytes");
    try writer.interface.flush();
    file.close(testing.io);

    const dir = try std.Io.Dir.openDir(tmp.dir, testing.io, ".", .{});
    var loose = try CookedStore.initFromDir(testing.allocator, ".", dir);
    defer loose.deinit(testing.allocator, testing.io);

    const bytes = try loose.readAlloc(testing.allocator, testing.io, "asset.zmesh");
    defer testing.allocator.free(bytes);
    try testing.expectEqualStrings("asset bytes", bytes);
}

test "FileSource maps missing files to AssetNotFound" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir = try std.Io.Dir.openDir(tmp.dir, testing.io, ".", .{});
    var loose = try CookedStore.initFromDir(testing.allocator, ".", dir);
    defer loose.deinit(testing.allocator, testing.io);

    try testing.expectError(error.FileNotFound, loose.readAlloc(testing.allocator, testing.io, "missing.zmesh"));
}

test "FileSource rejects paths outside the asset root" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir = try std.Io.Dir.openDir(tmp.dir, testing.io, ".", .{});
    var loose = try CookedStore.initFromDir(testing.allocator, ".", dir);
    defer loose.deinit(testing.allocator, testing.io);

    try testing.expectError(zimp.path.Error.ParentTraversalNotAllowed, loose.readAlloc(testing.allocator, testing.io, "../outside.zmesh"));
}
