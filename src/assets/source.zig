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

pub const AssetSource = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        readAlloc: *const fn (
            ptr: *anyopaque,
            allocator: std.mem.Allocator,
            io: std.Io,
            normalized_path: []const u8,
        ) anyerror![]u8,
        deinit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, io: std.Io) void,
    };

    pub fn readAlloc(
        self: AssetSource,
        allocator: std.mem.Allocator,
        io: std.Io,
        normalized_path: []const u8,
    ) ![]u8 {
        return self.vtable.readAlloc(self.ptr, allocator, io, normalized_path);
    }

    pub fn deinit(self: AssetSource, allocator: std.mem.Allocator, io: std.Io) void {
        self.vtable.deinit(self.ptr, allocator, io);
    }
};

pub const FileSource = struct {
    root: []u8,
    dir: std.Io.Dir,

    const max_asset_bytes: usize = 512 * 1024 * 1024;

    pub fn init(allocator: std.mem.Allocator, io: std.Io, root: []const u8) !FileSource {
        const cwd = std.Io.Dir.cwd();
        const dir = try std.Io.Dir.openDir(cwd, io, root, .{});
        errdefer dir.close(io);
        return initFromDir(allocator, root, dir);
    }

    pub fn initFromDir(allocator: std.mem.Allocator, root: []const u8, dir: std.Io.Dir) !FileSource {
        const owned_root = try allocator.dupe(u8, root);
        return .{
            .root = owned_root,
            .dir = dir,
        };
    }

    pub fn createSource(
        allocator: std.mem.Allocator,
        io: std.Io,
        root: []const u8,
    ) !AssetSource {
        const source_ptr = try allocator.create(FileSource);
        errdefer allocator.destroy(source_ptr);
        source_ptr.* = try FileSource.init(allocator, io, root);
        return source_ptr.source();
    }

    pub fn source(self: *FileSource) AssetSource {
        return .{
            .ptr = self,
            .vtable = &.{
                .readAlloc = readAllocThunk,
                .deinit = deinitThunk,
            },
        };
    }

    pub fn readAlloc(
        self: *FileSource,
        allocator: std.mem.Allocator,
        io: std.Io,
        normalized_path: []const u8,
    ) ![]u8 {
        zimp.runtime.validateVirtualPath(normalized_path) catch return AssetError.InvalidPath;
        return self.dir.readFileAlloc(io, normalized_path, allocator, .limited(max_asset_bytes)) catch |err| switch (err) {
            error.FileNotFound, error.NotDir, error.IsDir => AssetError.AssetNotFound,
            error.OutOfMemory => AssetError.OutOfMemory,
            else => err,
        };
    }

    pub fn deinit(self: *FileSource, allocator: std.mem.Allocator, io: std.Io) void {
        self.dir.close(io);
        allocator.free(self.root);
    }

    fn readAllocThunk(
        ptr: *anyopaque,
        allocator: std.mem.Allocator,
        io: std.Io,
        normalized_path: []const u8,
    ) anyerror![]u8 {
        const self: *FileSource = @ptrCast(@alignCast(ptr));
        return self.readAlloc(allocator, io, normalized_path);
    }

    fn deinitThunk(ptr: *anyopaque, allocator: std.mem.Allocator, io: std.Io) void {
        const self: *FileSource = @ptrCast(@alignCast(ptr));
        self.deinit(allocator, io);
        allocator.destroy(self);
    }
};

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
    var loose = try FileSource.initFromDir(testing.allocator, ".", dir);
    defer loose.deinit(testing.allocator, testing.io);

    const bytes = try loose.readAlloc(testing.allocator, testing.io, "asset.zmesh");
    defer testing.allocator.free(bytes);
    try testing.expectEqualStrings("asset bytes", bytes);
}

test "FileSource maps missing files to AssetNotFound" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir = try std.Io.Dir.openDir(tmp.dir, testing.io, ".", .{});
    var loose = try FileSource.initFromDir(testing.allocator, ".", dir);
    defer loose.deinit(testing.allocator, testing.io);

    try testing.expectError(AssetError.AssetNotFound, loose.readAlloc(testing.allocator, testing.io, "missing.zmesh"));
}
