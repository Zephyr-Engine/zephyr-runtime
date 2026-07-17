const std = @import("std");
const SceneEntityId = @import("zimp").SceneEntityId;
const EntityID = @import("zcs").EntityID;

/// Bidirectional bijection between persisted scene-entity identity
/// (`SceneEntityId`, a UUID stored in scene files) and live runtime handles
/// (`EntityID`, valid only for the current world). One instance exists per
/// instantiated scene; scene instantiation inserts a pair per spawned entity
/// and despawn removes it.
///
/// This is a plain container: it never touches the ECS and has no lifecycle
/// hooks. Runtime handles are never persisted — the map is rebuilt every
/// time a scene is instantiated.
pub const SceneEntityMap = struct {
    allocator: std.mem.Allocator,
    scene_to_runtime: std.AutoHashMapUnmanaged(SceneEntityId, EntityID),
    // Keyed by EntityID.toRaw() so lookups are independent of packed-struct
    // hashing details; the API surface only speaks EntityID.
    runtime_to_scene: std.AutoHashMapUnmanaged(u64, SceneEntityId),

    pub const InsertError = error{
        OutOfMemory,
        ZeroSceneEntityId,
        NilEntity,
        DuplicateSceneEntityId,
        DuplicateRuntimeEntity,
    };

    pub fn init(allocator: std.mem.Allocator) SceneEntityMap {
        return .{
            .allocator = allocator,
            .scene_to_runtime = .empty,
            .runtime_to_scene = .empty,
        };
    }

    pub fn deinit(self: *SceneEntityMap) void {
        self.scene_to_runtime.deinit(self.allocator);
        self.runtime_to_scene.deinit(self.allocator);
    }

    /// Register a (stable, runtime) pair. The map is a strict bijection:
    /// re-inserting either side is an error. On any failure neither side is
    /// modified.
    pub fn insert(self: *SceneEntityMap, stable: SceneEntityId, runtime: EntityID) InsertError!void {
        if (stable.isZero()) return InsertError.ZeroSceneEntityId;
        if (runtime.eql(EntityID.nil)) return InsertError.NilEntity;

        const fwd = try self.scene_to_runtime.getOrPut(self.allocator, stable);
        if (fwd.found_existing) return InsertError.DuplicateSceneEntityId;
        errdefer _ = self.scene_to_runtime.remove(stable);

        const rev = try self.runtime_to_scene.getOrPut(self.allocator, runtime.toRaw());
        if (rev.found_existing) {
            _ = self.scene_to_runtime.remove(stable);
            return InsertError.DuplicateRuntimeEntity;
        }

        fwd.value_ptr.* = runtime;
        rev.value_ptr.* = stable;
    }

    pub fn getRuntime(self: *const SceneEntityMap, stable: SceneEntityId) ?EntityID {
        return self.scene_to_runtime.get(stable);
    }

    pub fn getStable(self: *const SceneEntityMap, runtime: EntityID) ?SceneEntityId {
        return self.runtime_to_scene.get(runtime.toRaw());
    }

    /// Remove a pair by its stable id; returns the runtime handle it mapped
    /// to, or null if absent. Both directions are removed.
    pub fn removeByStable(self: *SceneEntityMap, stable: SceneEntityId) ?EntityID {
        const kv = self.scene_to_runtime.fetchRemove(stable) orelse return null;
        _ = self.runtime_to_scene.remove(kv.value.toRaw());
        return kv.value;
    }

    /// Remove a pair by its runtime handle; returns the stable id it mapped
    /// to, or null if absent. Both directions are removed.
    pub fn removeByRuntime(self: *SceneEntityMap, runtime: EntityID) ?SceneEntityId {
        const kv = self.runtime_to_scene.fetchRemove(runtime.toRaw()) orelse return null;
        _ = self.scene_to_runtime.remove(kv.value);
        return kv.value;
    }

    pub fn count(self: *const SceneEntityMap) usize {
        return self.scene_to_runtime.count();
    }

    pub fn clearRetainingCapacity(self: *SceneEntityMap) void {
        self.scene_to_runtime.clearRetainingCapacity();
        self.runtime_to_scene.clearRetainingCapacity();
    }

    pub const Entry = struct {
        stable: SceneEntityId,
        runtime: EntityID,
    };

    pub const Iterator = struct {
        inner: std.AutoHashMapUnmanaged(SceneEntityId, EntityID).Iterator,

        pub fn next(self: *Iterator) ?Entry {
            const kv = self.inner.next() orelse return null;
            return .{ .stable = kv.key_ptr.*, .runtime = kv.value_ptr.* };
        }
    };

    /// Iterate all (stable, runtime) pairs, e.g. for a despawn sweep when a
    /// scene instance is torn down. Order is unspecified.
    pub fn iterator(self: *const SceneEntityMap) Iterator {
        return .{ .inner = self.scene_to_runtime.iterator() };
    }
};

const testing = std.testing;

fn testStableId(seed: u64) SceneEntityId {
    var prng = std.Random.DefaultPrng.init(seed);
    return SceneEntityId.v4(prng.random());
}

test "SceneEntityMap insert and bidirectional lookup" {
    var map = SceneEntityMap.init(testing.allocator);
    defer map.deinit();

    const s0 = testStableId(1);
    const s1 = testStableId(2);
    const r0: EntityID = .{ .index = 0, .generation = 1 };
    const r1: EntityID = .{ .index = 1, .generation = 1 };

    try map.insert(s0, r0);
    try map.insert(s1, r1);

    try testing.expectEqual(@as(usize, 2), map.count());
    try testing.expect(map.getRuntime(s0).?.eql(r0));
    try testing.expect(map.getRuntime(s1).?.eql(r1));
    try testing.expect(map.getStable(r0).?.eql(s0));
    try testing.expect(map.getStable(r1).?.eql(s1));
    try testing.expectEqual(@as(?EntityID, null), map.getRuntime(testStableId(99)));
    try testing.expectEqual(@as(?SceneEntityId, null), map.getStable(.{ .index = 7, .generation = 3 }));
}

test "SceneEntityMap rejects zero and nil" {
    var map = SceneEntityMap.init(testing.allocator);
    defer map.deinit();

    const r: EntityID = .{ .index = 0, .generation = 1 };
    try testing.expectError(error.ZeroSceneEntityId, map.insert(SceneEntityId.zero, r));
    try testing.expectError(error.NilEntity, map.insert(testStableId(1), EntityID.nil));
    try testing.expectEqual(@as(usize, 0), map.count());
}

test "SceneEntityMap rejects duplicates without partial mutation" {
    var map = SceneEntityMap.init(testing.allocator);
    defer map.deinit();

    const s0 = testStableId(1);
    const s1 = testStableId(2);
    const r0: EntityID = .{ .index = 0, .generation = 1 };
    const r1: EntityID = .{ .index = 1, .generation = 1 };

    try map.insert(s0, r0);

    // Duplicate stable id: nothing changes.
    try testing.expectError(error.DuplicateSceneEntityId, map.insert(s0, r1));
    try testing.expectEqual(@as(usize, 1), map.count());
    try testing.expect(map.getRuntime(s0).?.eql(r0));
    try testing.expectEqual(@as(?SceneEntityId, null), map.getStable(r1));

    // Duplicate runtime handle: the new stable key is rolled back.
    try testing.expectError(error.DuplicateRuntimeEntity, map.insert(s1, r0));
    try testing.expectEqual(@as(usize, 1), map.count());
    try testing.expectEqual(@as(?EntityID, null), map.getRuntime(s1));
    try testing.expect(map.getStable(r0).?.eql(s0));
}

test "SceneEntityMap removes clean both directions" {
    var map = SceneEntityMap.init(testing.allocator);
    defer map.deinit();

    const s0 = testStableId(1);
    const s1 = testStableId(2);
    const r0: EntityID = .{ .index = 0, .generation = 1 };
    const r1: EntityID = .{ .index = 1, .generation = 1 };

    try map.insert(s0, r0);
    try map.insert(s1, r1);

    const removed_runtime = map.removeByStable(s0).?;
    try testing.expect(removed_runtime.eql(r0));
    try testing.expectEqual(@as(?EntityID, null), map.getRuntime(s0));
    try testing.expectEqual(@as(?SceneEntityId, null), map.getStable(r0));

    const removed_stable = map.removeByRuntime(r1).?;
    try testing.expect(removed_stable.eql(s1));
    try testing.expectEqual(@as(?EntityID, null), map.getRuntime(s1));
    try testing.expectEqual(@as(?SceneEntityId, null), map.getStable(r1));

    try testing.expectEqual(@as(usize, 0), map.count());
    try testing.expectEqual(@as(?EntityID, null), map.removeByStable(s0));
    try testing.expectEqual(@as(?SceneEntityId, null), map.removeByRuntime(r1));

    // Removed pairs can be re-inserted (e.g. respawn maps the stable id to a
    // fresh handle).
    const r0b: EntityID = .{ .index = 0, .generation = 2 };
    try map.insert(s0, r0b);
    try testing.expect(map.getRuntime(s0).?.eql(r0b));
}

test "SceneEntityMap clear and iterate" {
    var map = SceneEntityMap.init(testing.allocator);
    defer map.deinit();

    const s0 = testStableId(1);
    const s1 = testStableId(2);
    const r0: EntityID = .{ .index = 0, .generation = 1 };
    const r1: EntityID = .{ .index = 1, .generation = 1 };
    try map.insert(s0, r0);
    try map.insert(s1, r1);

    var seen: usize = 0;
    var it = map.iterator();
    while (it.next()) |entry| {
        try testing.expect(map.getRuntime(entry.stable).?.eql(entry.runtime));
        seen += 1;
    }
    try testing.expectEqual(@as(usize, 2), seen);

    map.clearRetainingCapacity();
    try testing.expectEqual(@as(usize, 0), map.count());
    try testing.expectEqual(@as(?EntityID, null), map.getRuntime(s0));
    try map.insert(s0, r0);
    try testing.expectEqual(@as(usize, 1), map.count());
}
