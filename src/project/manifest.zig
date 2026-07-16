const std = @import("std");

const path = @import("zimp").path;

const ProjectId = @import("../core/id/id_types.zig").ProjectId;

const MANIFEST_VERSION: u32 = 1;
const DEFAULT_COOKED_ASSETS_DIR = ".zephyr/cooked";
const DEFAULT_ASSETS_DIR = ".zephyr/assets";
const DEFAULT_SCENES_DIR = ".zephyr/scenes";
const DEFAULT_NAME = "Untitled Project";
const DEFAULT_GENERATED_DIR = ".zephyr";
const DEFAULT_FORMAT = "zephyr.proj";
pub const default_manifest_path = DEFAULT_GENERATED_DIR ++ "/" ++ DEFAULT_FORMAT;

pub const ProjectManifest = struct {
    format: []const u8 = DEFAULT_FORMAT,
    version: u32 = MANIFEST_VERSION,
    name: []const u8 = DEFAULT_NAME,
    project_id: ProjectId,
    assets_dir: []const u8 = DEFAULT_ASSETS_DIR,
    scenes_dir: []const u8 = DEFAULT_SCENES_DIR,
    generated_dir: []const u8 = DEFAULT_GENERATED_DIR,
    cooked_assets_dir: []const u8 = DEFAULT_COOKED_ASSETS_DIR,
    default_scene: ?[]const u8 = null,

    pub fn load(allocator: std.mem.Allocator, io: std.Io, file: []const u8) !ProjectManifest {
        const normalized_path = try path.normalizeVirtual(allocator, file);
        defer allocator.free(normalized_path);

        const cwd = std.Io.Dir.cwd();
        const dir = try cwd.openDir(io, ".", .{});
        defer dir.close(io);

        return loadFromDir(allocator, io, dir, normalized_path);
    }

    pub fn loadFromDir(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, file: []const u8) !ProjectManifest {
        const normalized_path = try path.normalizeVirtual(allocator, file);
        defer allocator.free(normalized_path);

        try path.validateVirtual(normalized_path);
        const bytes = try dir.readFileAlloc(io, normalized_path, allocator, .limited(4096));
        defer allocator.free(bytes);

        return std.json.parseFromSliceLeaky(ProjectManifest, allocator, bytes, .{
            .allocate = .alloc_always,
        });
    }

    pub fn deinit(self: ProjectManifest, allocator: std.mem.Allocator) void {
        freeIfNotDefault(allocator, self.name, DEFAULT_NAME);
        freeIfNotDefault(allocator, self.format, DEFAULT_FORMAT);
        freeIfNotDefault(allocator, self.assets_dir, DEFAULT_ASSETS_DIR);
        freeIfNotDefault(allocator, self.scenes_dir, DEFAULT_SCENES_DIR);
        freeIfNotDefault(allocator, self.generated_dir, DEFAULT_GENERATED_DIR);
        freeIfNotDefault(allocator, self.cooked_assets_dir, DEFAULT_COOKED_ASSETS_DIR);
        if (self.default_scene) |default_scene| {
            allocator.free(default_scene);
        }
    }

    pub fn assetsPath(self: *const ProjectManifest) []const u8 {
        return self.assets_dir;
    }

    pub fn cookedAssetsPath(self: *const ProjectManifest) []const u8 {
        return self.cooked_assets_dir;
    }

    pub fn save(self: *const ProjectManifest, allocator: std.mem.Allocator, io: std.Io, root_dir: std.Io.Dir) !void {
        try path.validateVirtual(self.generated_dir);
        try path.validateVirtual(self.format);

        var generated_dir = try root_dir.createDirPathOpen(io, self.generated_dir, .{});
        defer generated_dir.close(io);

        const bytes = try std.json.Stringify.valueAlloc(allocator, self, .{ .whitespace = .indent_2 });
        defer allocator.free(bytes);

        try generated_dir.writeFile(io, .{
            .sub_path = self.format,
            .data = bytes,
            .flags = .{ .truncate = true },
        });
    }
};

pub const Project = struct {
    manifest: ProjectManifest,
    root_dir: std.Io.Dir,

    pub fn deinit(self: *Project, allocator: std.mem.Allocator, io: std.Io) void {
        self.manifest.deinit(allocator);
        self.root_dir.close(io);
    }
};

fn freeIfNotDefault(allocator: std.mem.Allocator, value: []const u8, default_value: []const u8) void {
    if (value.ptr != default_value.ptr) {
        allocator.free(value);
    }
}

const testing = std.testing;

test "ProjectManifest.save writes generated manifest file" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const manifest: ProjectManifest = .{
        .project_id = ProjectId.zero,
    };

    try manifest.save(testing.allocator, testing.io, tmp.dir);

    const bytes = try tmp.dir.readFileAlloc(testing.io, ".zephyr/zephyr.proj", testing.allocator, .limited(4096));
    defer testing.allocator.free(bytes);
    try testing.expect(std.mem.indexOf(u8, bytes, "\"project_id\": \"00000000-0000-0000-0000-000000000000\"") != null);

    const parsed = try std.json.parseFromSlice(ProjectManifest, testing.allocator, bytes, .{});
    defer parsed.deinit();
    try testing.expectEqualStrings(".zephyr", parsed.value.generated_dir);
    try testing.expectEqualStrings(".zephyr/assets", parsed.value.assets_dir);
    try testing.expectEqualStrings(".zephyr/cooked", parsed.value.cooked_assets_dir);
    try testing.expectEqualStrings("zephyr.proj", parsed.value.format);
    try testing.expect(parsed.value.project_id.eql(ProjectId.zero));
}

test "ProjectManifest parses project_id from canonical UUID text" {
    const bytes =
        \\{
        \\  "name": "Test Project",
        \\  "project_id": "00000000-0000-0000-0000-000000000000"
        \\}
    ;

    const parsed = try std.json.parseFromSlice(ProjectManifest, testing.allocator, bytes, .{});
    defer parsed.deinit();
    try testing.expect(parsed.value.project_id.eql(ProjectId.zero));
}

test "ProjectManifest.deinit handles default literal fields" {
    const manifest: ProjectManifest = .{
        .project_id = ProjectId.zero,
    };

    manifest.deinit(testing.allocator);
}

test "ProjectManifest.deinit frees strings allocated during leaky parsing" {
    const bytes =
        \\{
        \\  "format": "custom.proj",
        \\  "name": "Test Project",
        \\  "project_id": "00000000-0000-0000-0000-000000000000",
        \\  "assets_dir": "game-assets",
        \\  "scenes_dir": "game-scenes",
        \\  "generated_dir": ".cache",
        \\  "cooked_assets_dir": ".cache/cooked",
        \\  "default_scene": "game-scenes/main.scene"
        \\}
    ;

    const manifest = try std.json.parseFromSliceLeaky(ProjectManifest, testing.allocator, bytes, .{
        .allocate = .alloc_always,
    });
    defer manifest.deinit(testing.allocator);

    try testing.expectEqualStrings("custom.proj", manifest.format);
    try testing.expectEqualStrings("game-scenes/main.scene", manifest.default_scene.?);
}

test "ProjectManifest path helpers expose configured asset roots" {
    const manifest: ProjectManifest = .{
        .name = "Test Project",
        .project_id = ProjectId.zero,
        .assets_dir = "game-assets",
        .cooked_assets_dir = ".cache/cooked",
    };

    try testing.expectEqualStrings("game-assets", manifest.assetsPath());
    try testing.expectEqualStrings(".cache/cooked", manifest.cookedAssetsPath());
}
