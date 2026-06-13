const std = @import("std");
const zimp = @import("zimp");

const asset_uuid = @import("uuid.zig");
const source_mod = @import("source.zig");

const AssetId = asset_uuid.AssetId;
const AssetKind = asset_uuid.AssetKind;
const AssetRoots = source_mod.AssetRoots;
const AssetSource = source_mod.AssetSource;
const AssetError = source_mod.AssetError;
const FileSource = source_mod.FileSource;
const Mesh = @import("../graphics/mesh.zig").Mesh;
const Material = @import("../graphics/material.zig").Material;
const Shader = @import("../graphics/opengl/shader.zig").Shader;
const Texture2D = @import("../graphics/opengl/texture.zig").Texture2D;

pub const AssetState = enum {
    queued,
    loading,
    ready_for_finalize,
    waiting_dependencies,
    finalizing,
    loaded,
    failed,
};

pub const Asset = union(AssetKind) {
    mesh: *Mesh,
    material: *Material,
    texture: *Texture2D,
    shader_stage: *zimp.ZShader,
    shader_program: *Shader,

    fn deinit(self: Asset, allocator: std.mem.Allocator, worker_allocator: std.mem.Allocator) void {
        switch (self) {
            .mesh => |mesh| {
                mesh.deinit();
                allocator.destroy(mesh);
            },
            .material => |material| {
                material.deinit();
                allocator.destroy(material);
            },
            .texture => |texture| {
                texture.deinit();
                allocator.destroy(texture);
            },
            .shader_stage => |shader| {
                shader.deinit(worker_allocator);
                allocator.destroy(shader);
            },
            .shader_program => |shader| {
                shader.deinit();
                allocator.destroy(shader);
            },
        }
    }
};

const AssetRecord = struct {
    id: AssetId,
    kind: AssetKind,
    path: ?[]u8,
    state: AssetState,
    asset: ?Asset = null,
    cooked: ?zimp.runtime.Asset = null,
    failure: ?anyerror = null,

    fn deinit(
        self: *AssetRecord,
        allocator: std.mem.Allocator,
        worker_allocator: std.mem.Allocator,
    ) void {
        if (self.asset) |asset| {
            asset.deinit(allocator, worker_allocator);
            self.asset = null;
        }
        if (self.cooked) |*cooked| {
            cooked.deinit(worker_allocator);
            self.cooked = null;
        }
        if (self.path) |path| {
            allocator.free(path);
            self.path = null;
        }
    }
};

const SynchronizedAllocator = struct {
    child: std.mem.Allocator,
    io: std.Io,
    mutex: std.Io.Mutex = .init,

    fn allocator(self: *SynchronizedAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(ptr: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *SynchronizedAllocator = @ptrCast(@alignCast(ptr));
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        return self.child.rawAlloc(len, alignment, ret_addr);
    }

    fn resize(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *SynchronizedAllocator = @ptrCast(@alignCast(ptr));
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        return self.child.rawResize(memory, alignment, new_len, ret_addr);
    }

    fn remap(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *SynchronizedAllocator = @ptrCast(@alignCast(ptr));
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        return self.child.rawRemap(memory, alignment, new_len, ret_addr);
    }

    fn free(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *SynchronizedAllocator = @ptrCast(@alignCast(ptr));
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        self.child.rawFree(memory, alignment, ret_addr);
    }
};

const LoadJob = struct {
    record: *AssetRecord,
};

const ReaderPool = struct {
    allocator: std.mem.Allocator,
    worker_allocator: std.mem.Allocator,
    io: std.Io,
    source: AssetSource,

    mutex: std.Io.Mutex = .init,
    cond: std.Io.Condition = .init,
    jobs: std.ArrayList(LoadJob) = .empty,
    workers: []std.Thread = &.{},
    stopping: bool = false,

    fn create(
        allocator: std.mem.Allocator,
        worker_allocator: std.mem.Allocator,
        io: std.Io,
        source: AssetSource,
        worker_count: usize,
    ) !*ReaderPool {
        const pool = try allocator.create(ReaderPool);
        errdefer allocator.destroy(pool);

        pool.* = .{
            .allocator = allocator,
            .worker_allocator = worker_allocator,
            .io = io,
            .source = source,
        };

        pool.workers = try allocator.alloc(std.Thread, worker_count);
        errdefer allocator.free(pool.workers);

        var spawned: usize = 0;
        errdefer {
            pool.requestStop();
            for (pool.workers[0..spawned]) |thread| thread.join();
        }
        while (spawned < worker_count) : (spawned += 1) {
            pool.workers[spawned] = try std.Thread.spawn(.{}, workerMain, .{pool});
        }

        return pool;
    }

    fn destroy(self: *ReaderPool) void {
        self.requestStop();
        for (self.workers) |thread| {
            thread.join();
        }
        self.allocator.free(self.workers);
        self.jobs.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn requestStop(self: *ReaderPool) void {
        self.mutex.lockUncancelable(self.io);
        self.stopping = true;
        self.cond.broadcast(self.io);
        self.mutex.unlock(self.io);
    }

    fn enqueueLocked(self: *ReaderPool, record: *AssetRecord) !void {
        try self.jobs.append(self.allocator, .{ .record = record });
        self.cond.signal(self.io);
    }

    fn workerMain(self: *ReaderPool) void {
        while (true) {
            const job = self.nextJob() orelse return;
            self.process(job);
        }
    }

    fn nextJob(self: *ReaderPool) ?LoadJob {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);

        while (!self.stopping and self.jobs.items.len == 0) {
            self.cond.waitUncancelable(self.io, &self.mutex);
        }

        if (self.stopping and self.jobs.items.len == 0) {
            return null;
        }

        return self.jobs.orderedRemove(0);
    }

    fn process(self: *ReaderPool, job: LoadJob) void {
        self.mutex.lockUncancelable(self.io);
        if (job.record.state != .queued) {
            self.mutex.unlock(self.io);
            return;
        }
        job.record.state = .loading;
        self.cond.broadcast(self.io);
        self.mutex.unlock(self.io);

        const loaded = self.loadCookedAsset(job.record) catch |err| {
            self.mutex.lockUncancelable(self.io);
            job.record.failure = err;
            job.record.state = .failed;
            self.cond.broadcast(self.io);
            self.mutex.unlock(self.io);
            return;
        };

        self.mutex.lockUncancelable(self.io);
        job.record.cooked = loaded;
        job.record.state = .ready_for_finalize;
        self.cond.broadcast(self.io);
        self.mutex.unlock(self.io);
    }

    fn loadCookedAsset(self: *ReaderPool, record: *AssetRecord) !zimp.runtime.Asset {
        const normalized_path = record.path orelse return AssetError.AssetNotFound;
        const bytes = try self.source.readAlloc(self.worker_allocator, self.io, normalized_path);
        defer self.worker_allocator.free(bytes);

        var reader = std.Io.Reader.fixed(bytes);
        return zimp.runtime.loadFromReader(self.worker_allocator, &reader, runtimeKind(record.kind));
    }
};

pub const AssetManager = struct {
    backing_allocator: std.mem.Allocator,
    allocator: std.mem.Allocator,
    worker_allocator_state: *SynchronizedAllocator,
    worker_allocator: std.mem.Allocator,
    io: std.Io,
    source: AssetSource,
    pool: *ReaderPool,

    assets: std.AutoHashMap(AssetId, *AssetRecord),
    paths: std.StringHashMap(AssetId),
    shader_programs: std.StringHashMap(AssetId),

    pub const Options = struct {
        worker_count: ?usize = null,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        source: AssetSource,
    ) !AssetManager {
        return initWithOptions(allocator, io, source, .{});
    }

    pub fn initWithOptions(
        allocator: std.mem.Allocator,
        io: std.Io,
        source: AssetSource,
        options: Options,
    ) !AssetManager {
        const worker_count = options.worker_count orelse defaultWorkerCount();
        if (worker_count == 0) return AssetError.LoadFailed;

        const worker_allocator_state = try allocator.create(SynchronizedAllocator);
        errdefer allocator.destroy(worker_allocator_state);
        worker_allocator_state.* = .{
            .child = allocator,
            .io = io,
        };
        const managed_allocator = worker_allocator_state.allocator();

        const pool = try ReaderPool.create(
            managed_allocator,
            managed_allocator,
            io,
            source,
            worker_count,
        );
        errdefer {
            pool.destroy();
            allocator.destroy(worker_allocator_state);
        }

        return .{
            .backing_allocator = allocator,
            .allocator = managed_allocator,
            .worker_allocator_state = worker_allocator_state,
            .worker_allocator = managed_allocator,
            .io = io,
            .source = source,
            .pool = pool,
            .assets = std.AutoHashMap(AssetId, *AssetRecord).init(managed_allocator),
            .paths = std.StringHashMap(AssetId).init(managed_allocator),
            .shader_programs = std.StringHashMap(AssetId).init(managed_allocator),
        };
    }

    pub fn initFiles(
        allocator: std.mem.Allocator,
        io: std.Io,
        roots: AssetRoots,
    ) !AssetManager {
        return initFilesWithOptions(allocator, io, roots, .{});
    }

    pub fn initFilesWithOptions(
        allocator: std.mem.Allocator,
        io: std.Io,
        roots: AssetRoots,
        options: Options,
    ) !AssetManager {
        const source = try FileSource.createSource(
            allocator,
            io,
            roots.cooked_root,
        );
        errdefer source.deinit(allocator, io);
        return initWithOptions(allocator, io, source, options);
    }

    pub fn deinit(self: *AssetManager) void {
        self.pool.destroy();

        var assets_it = self.assets.valueIterator();
        while (assets_it.next()) |record_ptr| {
            const record = record_ptr.*;
            record.deinit(self.allocator, self.worker_allocator);
            self.allocator.destroy(record);
        }
        self.assets.deinit();
        self.paths.deinit();

        var shader_it = self.shader_programs.keyIterator();
        while (shader_it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.shader_programs.deinit();

        self.source.deinit(self.allocator, self.io);
        self.backing_allocator.destroy(self.worker_allocator_state);
    }

    pub fn register(self: *AssetManager, comptime T: type, path: []const u8) !AssetId {
        const expected = comptime kindFor(T);
        if (expected == .shader_program) return AssetError.WrongAssetKind;
        return self.requestKind(expected, path);
    }

    pub fn registerSync(self: *AssetManager, comptime T: type, path: []const u8) !AssetId {
        const id = try self.register(T, path);
        try self.wait(id);
        return id;
    }

    pub fn state(self: *AssetManager, id: AssetId) ?AssetState {
        self.lock();
        defer self.unlock();
        const record = self.assets.get(id) orelse return null;
        return record.state;
    }

    pub fn wait(self: *AssetManager, id: AssetId) !void {
        while (true) {
            try self.pump();

            self.lock();
            const record = self.assets.get(id) orelse {
                self.unlock();
                return AssetError.AssetNotFound;
            };
            switch (record.state) {
                .loaded => {
                    self.unlock();
                    return;
                },
                .failed => {
                    const err = record.failure orelse AssetError.LoadFailed;
                    self.unlock();
                    return err;
                },
                .ready_for_finalize, .waiting_dependencies, .finalizing => {
                    self.unlock();
                },
                .queued, .loading => {
                    self.pool.cond.waitUncancelable(self.io, &self.pool.mutex);
                    self.unlock();
                },
            }
        }
    }

    pub fn pump(self: *AssetManager) !void {
        var ready: std.ArrayList(*AssetRecord) = .empty;
        defer ready.deinit(self.allocator);

        {
            self.lock();
            defer self.unlock();
            var it = self.assets.valueIterator();
            while (it.next()) |record_ptr| {
                const record = record_ptr.*;
                switch (record.state) {
                    .ready_for_finalize, .waiting_dependencies => {
                        try ready.append(self.allocator, record);
                        record.state = .finalizing;
                    },
                    else => {},
                }
            }
        }

        for (ready.items) |record| {
            const result = self.finalizeRecord(record) catch |err| {
                self.lock();
                self.failRecordLocked(record, err);
                self.unlock();
                continue;
            };

            self.lock();
            switch (result) {
                .loaded => |asset| {
                    record.asset = asset;
                    record.state = .loaded;
                    record.failure = null;
                },
                .waiting => {
                    record.state = .waiting_dependencies;
                },
            }
            self.pool.cond.broadcast(self.io);
            self.unlock();
        }
    }

    pub fn get(self: *AssetManager, comptime T: type, id: AssetId) ?*T {
        const expected = comptime kindFor(T);
        self.lock();
        defer self.unlock();

        const record = self.assets.get(id) orelse return null;
        if (record.state != .loaded) return null;
        const asset = record.asset orelse return null;
        return switch (expected) {
            .mesh => switch (asset) {
                .mesh => |mesh| mesh,
                else => null,
            },
            .material => switch (asset) {
                .material => |material| material,
                else => null,
            },
            .texture => switch (asset) {
                .texture => |texture| texture,
                else => null,
            },
            .shader_stage => null,
            .shader_program => switch (asset) {
                .shader_program => |shader| shader,
                else => null,
            },
        };
    }

    pub fn pathFor(self: *AssetManager, id: AssetId) ?[]const u8 {
        self.lock();
        defer self.unlock();
        const record = self.assets.get(id) orelse return null;
        return record.path;
    }

    pub fn kindForId(self: *AssetManager, id: AssetId) ?AssetKind {
        self.lock();
        defer self.unlock();
        const record = self.assets.get(id) orelse return null;
        return record.kind;
    }

    pub fn loadMesh(self: *AssetManager, path: []const u8) !*Mesh {
        const id = try self.registerSync(Mesh, path);
        return self.get(Mesh, id).?;
    }

    pub fn loadMaterial(self: *AssetManager, path: []const u8) !*Material {
        const id = try self.registerSync(Material, path);
        return self.get(Material, id).?;
    }

    pub fn loadTexture(self: *AssetManager, path: []const u8) !*Texture2D {
        const id = try self.registerSync(Texture2D, path);
        return self.get(Texture2D, id).?;
    }

    fn requestKind(self: *AssetManager, expected: AssetKind, path: []const u8) !AssetId {
        const normalized_path = try self.normalizeExpected(path, expected);
        var path_owned = true;
        errdefer if (path_owned) self.allocator.free(normalized_path);

        self.lock();
        defer self.unlock();

        if (self.paths.get(normalized_path)) |cached| {
            self.allocator.free(normalized_path);
            path_owned = false;
            return cached;
        }

        const id = try self.newAssetIdLocked();
        const record = try self.allocator.create(AssetRecord);
        record.* = .{
            .id = id,
            .kind = expected,
            .path = normalized_path,
            .state = .queued,
        };
        path_owned = false;
        var record_owned = true;
        errdefer if (record_owned) {
            record.deinit(self.allocator, self.worker_allocator);
            self.allocator.destroy(record);
        };

        try self.assets.put(id, record);
        errdefer _ = self.assets.remove(id);
        try self.paths.put(record.path.?, id);
        errdefer _ = self.paths.remove(record.path.?);
        try self.pool.enqueueLocked(record);

        record_owned = false;
        return id;
    }

    const FinalizeResult = union(enum) {
        loaded: Asset,
        waiting,
    };

    fn finalizeRecord(self: *AssetManager, record: *AssetRecord) !FinalizeResult {
        return switch (record.kind) {
            .mesh => .{ .loaded = .{ .mesh = try self.finalizeMesh(record) } },
            .material => try self.finalizeMaterial(record),
            .texture => .{ .loaded = .{ .texture = try self.finalizeTexture(record) } },
            .shader_stage => .{ .loaded = .{ .shader_stage = try self.finalizeShaderStage(record) } },
            .shader_program => AssetError.WrongAssetKind,
        };
    }

    fn finalizeMesh(self: *AssetManager, record: *AssetRecord) !*Mesh {
        var cooked_asset = record.cooked orelse return AssetError.LoadFailed;
        record.cooked = null;
        defer cooked_asset.deinit(self.worker_allocator);

        const cooked_mesh = switch (cooked_asset) {
            .mesh => |mesh| mesh,
            else => return AssetError.WrongAssetKind,
        };

        const mesh = try self.allocator.create(Mesh);
        errdefer self.allocator.destroy(mesh);
        mesh.* = try Mesh.loadFromZMesh(cooked_mesh);
        errdefer mesh.deinit();

        return mesh;
    }

    fn finalizeTexture(self: *AssetManager, record: *AssetRecord) !*Texture2D {
        var cooked_asset = record.cooked orelse return AssetError.LoadFailed;
        record.cooked = null;
        defer cooked_asset.deinit(self.worker_allocator);

        const cooked_texture = switch (cooked_asset) {
            .texture => |texture| texture,
            else => return AssetError.WrongAssetKind,
        };

        const texture = try self.allocator.create(Texture2D);
        errdefer self.allocator.destroy(texture);
        texture.* = try Texture2D.init(cooked_texture);
        errdefer texture.deinit();

        return texture;
    }

    fn finalizeShaderStage(self: *AssetManager, record: *AssetRecord) !*zimp.ZShader {
        var cooked_asset = record.cooked orelse return AssetError.LoadFailed;
        record.cooked = null;
        errdefer cooked_asset.deinit(self.worker_allocator);

        const shader = switch (cooked_asset) {
            .shader => |stage| stage,
            else => return AssetError.WrongAssetKind,
        };

        const shader_ptr = try self.allocator.create(zimp.ZShader);
        shader_ptr.* = shader;
        return shader_ptr;
    }

    fn finalizeMaterial(self: *AssetManager, record: *AssetRecord) !FinalizeResult {
        const cooked_ptr = &(record.cooked orelse return AssetError.LoadFailed);
        const material_source_ptr = switch (cooked_ptr.*) {
            .material => |*source| source,
            else => return AssetError.WrongAssetKind,
        };

        const vertex_path = try zimp.runtime.resolveRelativeVirtualPath(
            self.allocator,
            record.path.?,
            material_source_ptr.vertex_shader_path,
        );
        defer self.allocator.free(vertex_path);
        const fragment_path = try zimp.runtime.resolveRelativeVirtualPath(
            self.allocator,
            record.path.?,
            material_source_ptr.fragment_shader_path,
        );
        defer self.allocator.free(fragment_path);

        const shader = try self.loadShaderProgramReady(vertex_path, fragment_path) orelse return .waiting;

        var texture_bindings: std.ArrayList(Material.TextureBinding) = .empty;
        errdefer texture_bindings.deinit(self.allocator);

        for (material_source_ptr.texture_slots) |slot| {
            if (slot.slot_index == std.math.maxInt(u16) or slot.cooked_path.len == 0) {
                continue;
            }

            const texture_path = try zimp.runtime.resolveRelativeVirtualPath(
                self.allocator,
                record.path.?,
                slot.cooked_path,
            );
            defer self.allocator.free(texture_path);

            const texture_id = try self.requestKind(.texture, texture_path);
            const texture = try self.loadedTexture(texture_id) orelse return .waiting;
            try texture_bindings.append(self.allocator, .{
                .unit = slot.slot_index,
                .texture = texture,
                .slot_name_hash = slot.slot_name_hash,
            });
        }

        const cooked_asset = record.cooked.?;
        record.cooked = null;

        var material_source = switch (cooked_asset) {
            .material => |source| source,
            else => unreachable,
        };
        var source_owned = true;
        errdefer if (source_owned) material_source.deinit(self.allocator);

        const texture_slice = try texture_bindings.toOwnedSlice(self.allocator);
        var texture_slice_owned = true;
        errdefer if (texture_slice_owned) self.allocator.free(texture_slice);

        const material = try self.allocator.create(Material);
        errdefer self.allocator.destroy(material);
        material.* = try Material.initFromSource(
            self.allocator,
            material_source,
            shader,
            texture_slice,
        );
        source_owned = false;
        texture_slice_owned = false;
        errdefer material.deinit();

        return .{ .loaded = .{ .material = material } };
    }

    fn loadShaderProgramReady(
        self: *AssetManager,
        vertex_path: []const u8,
        fragment_path: []const u8,
    ) !?*Shader {
        const normalized_vertex = try self.normalizeExpected(vertex_path, .shader_stage);
        defer self.allocator.free(normalized_vertex);
        const normalized_fragment = try self.normalizeExpected(fragment_path, .shader_stage);
        defer self.allocator.free(normalized_fragment);

        const lookup_key = try makeShaderProgramKey(self.allocator, normalized_vertex, normalized_fragment);
        var key_owned = true;
        defer if (key_owned) self.allocator.free(lookup_key);

        self.lock();
        if (self.shader_programs.get(lookup_key)) |id| {
            const record = self.assets.get(id).?;
            const shader = switch (record.asset.?) {
                .shader_program => |shader| shader,
                else => unreachable,
            };
            self.unlock();
            return shader;
        }
        self.unlock();

        const vertex_id = try self.requestKind(.shader_stage, normalized_vertex);
        const fragment_id = try self.requestKind(.shader_stage, normalized_fragment);
        const vertex_stage = try self.loadedShaderStage(vertex_id) orelse return null;
        const fragment_stage = try self.loadedShaderStage(fragment_id) orelse return null;

        if (vertex_stage.stage != .vertex or fragment_stage.stage != .fragment) {
            return AssetError.WrongAssetKind;
        }

        const shader = try self.allocator.create(Shader);
        errdefer self.allocator.destroy(shader);
        shader.* = try linkShaderProgram(self.allocator, vertex_stage, fragment_stage);
        errdefer shader.deinit();

        self.lock();
        defer self.unlock();

        if (self.shader_programs.get(lookup_key)) |id| {
            const record = self.assets.get(id).?;
            shader.deinit();
            self.allocator.destroy(shader);
            return switch (record.asset.?) {
                .shader_program => |cached| cached,
                else => unreachable,
            };
        }

        const id = try self.newAssetIdLocked();
        const record = try self.allocator.create(AssetRecord);
        record.* = .{
            .id = id,
            .kind = .shader_program,
            .path = null,
            .state = .loaded,
            .asset = .{ .shader_program = shader },
        };
        var record_owned = true;
        errdefer if (record_owned) {
            record.deinit(self.allocator, self.worker_allocator);
            self.allocator.destroy(record);
        };

        try self.assets.put(id, record);
        errdefer _ = self.assets.remove(id);
        try self.shader_programs.put(lookup_key, id);
        key_owned = false;
        record_owned = false;

        return shader;
    }

    fn loadedTexture(self: *AssetManager, id: AssetId) !?*Texture2D {
        self.lock();
        defer self.unlock();
        const record = self.assets.get(id) orelse return AssetError.AssetNotFound;
        if (record.state == .failed) return record.failure orelse AssetError.LoadFailed;
        if (record.state != .loaded) return null;
        return switch (record.asset.?) {
            .texture => |texture| texture,
            else => AssetError.WrongAssetKind,
        };
    }

    fn loadedShaderStage(self: *AssetManager, id: AssetId) !?*zimp.ZShader {
        self.lock();
        defer self.unlock();
        const record = self.assets.get(id) orelse return AssetError.AssetNotFound;
        if (record.state == .failed) return record.failure orelse AssetError.LoadFailed;
        if (record.state != .loaded) return null;
        return switch (record.asset.?) {
            .shader_stage => |shader| shader,
            else => AssetError.WrongAssetKind,
        };
    }

    fn failRecordLocked(self: *AssetManager, record: *AssetRecord, err: anyerror) void {
        if (record.cooked) |*cooked| {
            cooked.deinit(self.worker_allocator);
            record.cooked = null;
        }
        record.failure = err;
        record.state = .failed;
        self.pool.cond.broadcast(self.io);
    }

    fn normalizeExpected(self: *AssetManager, raw_path: []const u8, expected: AssetKind) ![]u8 {
        const normalized = zimp.runtime.normalizeVirtualPath(self.allocator, raw_path) catch return AssetError.InvalidPath;
        errdefer self.allocator.free(normalized);
        const actual = asset_uuid.inferKind(normalized) orelse return AssetError.UnsupportedAssetKind;
        if (actual != expected) return AssetError.WrongAssetKind;
        return normalized;
    }

    fn newAssetIdLocked(self: *AssetManager) !AssetId {
        while (true) {
            const random_source: std.Random.IoSource = .{ .io = self.io };
            const id = asset_uuid.Uuid.v4(random_source.interface());
            if (id.isZero()) continue;
            if (!self.assets.contains(id)) return id;
        }
    }

    fn lock(self: *AssetManager) void {
        self.pool.mutex.lockUncancelable(self.io);
    }

    fn unlock(self: *AssetManager) void {
        self.pool.mutex.unlock(self.io);
    }
};

fn defaultWorkerCount() usize {
    const cpu_count = std.Thread.getCpuCount() catch 2;
    if (cpu_count <= 1) return 1;
    return @min(cpu_count - 1, 4);
}

fn runtimeKind(kind: AssetKind) zimp.runtime.AssetType {
    return switch (kind) {
        .mesh => .mesh,
        .material => .material,
        .texture => .texture,
        .shader_stage => .shader,
        .shader_program => .shader,
    };
}

fn linkShaderProgram(
    allocator: std.mem.Allocator,
    vertex_stage: *const zimp.ZShader,
    fragment_stage: *const zimp.ZShader,
) !Shader {
    const vertex_source = try vertex_stage.baseSource();
    const fragment_source = try fragment_stage.baseSource();
    return Shader.init(allocator, vertex_source, fragment_source);
}

fn kindFor(comptime T: type) AssetKind {
    return switch (T) {
        Mesh => .mesh,
        Material => .material,
        Texture2D => .texture,
        Shader => .shader_program,
        else => @compileError("unsupported asset type: " ++ @typeName(T)),
    };
}

fn makeShaderProgramKey(
    allocator: std.mem.Allocator,
    vertex_path: []const u8,
    fragment_path: []const u8,
) ![]u8 {
    const key = try allocator.alloc(u8, vertex_path.len + 1 + fragment_path.len);
    @memcpy(key[0..vertex_path.len], vertex_path);
    key[vertex_path.len] = 0;
    @memcpy(key[vertex_path.len + 1 ..], fragment_path);
    return key;
}

test "makeShaderProgramKey includes both stage paths" {
    const key = try makeShaderProgramKey(std.testing.allocator, "basic.vert.zshdr", "basic.frag.zshdr");
    defer std.testing.allocator.free(key);
    try std.testing.expectEqualStrings("basic.vert.zshdr", key[0.."basic.vert.zshdr".len]);
    try std.testing.expectEqual(@as(u8, 0), key["basic.vert.zshdr".len]);
    try std.testing.expectEqualStrings("basic.frag.zshdr", key["basic.vert.zshdr".len + 1 ..]);
}

const TestSource = struct {
    reads: std.atomic.Value(usize) = .init(0),
    bytes: []const u8,

    fn source(self: *TestSource) AssetSource {
        return .{
            .ptr = self,
            .vtable = &.{
                .readAlloc = readAllocThunk,
                .deinit = deinitThunk,
            },
        };
    }

    fn readAllocThunk(
        ptr: *anyopaque,
        allocator: std.mem.Allocator,
        io: std.Io,
        normalized_path: []const u8,
    ) anyerror![]u8 {
        _ = io;
        _ = normalized_path;
        const self: *TestSource = @ptrCast(@alignCast(ptr));
        _ = self.reads.fetchAdd(1, .monotonic);
        return allocator.dupe(u8, self.bytes);
    }

    fn deinitThunk(ptr: *anyopaque, allocator: std.mem.Allocator, io: std.Io) void {
        _ = ptr;
        _ = allocator;
        _ = io;
    }
};

test "register deduplicates normalized paths before worker load finishes" {
    if (@import("builtin").single_threaded) return error.SkipZigTest;

    var source = TestSource{ .bytes = "not a cooked mesh" };
    var manager = try AssetManager.initWithOptions(
        std.testing.allocator,
        std.testing.io,
        source.source(),
        .{ .worker_count = 1 },
    );
    defer manager.deinit();

    const first = try manager.register(Mesh, "./asset.zmesh");
    const second = try manager.register(Mesh, "asset.zmesh");

    try std.testing.expectEqual(first, second);
    try std.testing.expectEqualStrings("asset.zmesh", manager.pathFor(first).?);

    manager.wait(first) catch {};
    try std.testing.expectEqual(AssetState.failed, manager.state(first).?);
    try std.testing.expectEqual(@as(usize, 1), source.reads.load(.monotonic));
}
