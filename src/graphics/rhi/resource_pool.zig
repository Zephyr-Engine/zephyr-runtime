const std = @import("std");

pub fn ResourcePool(comptime Resource: type) type {
    return struct {
        const Self = @This();

        pub const Allocation = struct {
            index: u32,
            generation: u32,
        };

        pub const Slot = struct {
            generation: u32 = 1,
            resource: ?Resource = null,
            next_free: ?u32 = null,
        };

        slots: std.ArrayList(Slot) = .empty,
        free_head: ?u32 = null,

        pub fn insert(self: *Self, allocator: std.mem.Allocator, resource: Resource) !Allocation {
            if (self.free_head) |index| {
                const slot = &self.slots.items[index];
                self.free_head = slot.next_free;
                slot.resource = resource;
                slot.next_free = null;
                return .{ .index = index, .generation = slot.generation };
            }

            const index: u32 = @intCast(self.slots.items.len);
            try self.slots.append(allocator, .{ .resource = resource });
            return .{ .index = index, .generation = 1 };
        }

        pub fn get(self: *Self, index: u32, generation: u32) ?*Resource {
            if (index >= self.slots.items.len) {
                return null;
            }

            const slot = &self.slots.items[index];
            if (slot.generation != generation) {
                return null;
            }
            return if (slot.resource) |*resource| resource else null;
        }

        pub fn remove(self: *Self, index: u32, generation: u32) ?Resource {
            const resource = (self.get(index, generation) orelse return null).*;
            const slot = &self.slots.items[index];

            slot.resource = null;
            slot.generation = nextGeneration(slot.generation);
            slot.next_free = self.free_head;
            self.free_head = index;
            return resource;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.slots.deinit(allocator);
            self.* = .{};
        }
    };
}

fn nextGeneration(current: u32) u32 {
    const next = current +% 1;
    return if (next == 0) 1 else next;
}

test "removed slots are reused with a new generation" {
    const testing = std.testing;
    const Pool = ResourcePool(u32);
    var pool: Pool = .{};
    defer pool.deinit(testing.allocator);

    const first = try pool.insert(testing.allocator, 10);
    try testing.expectEqual(@as(u32, 10), pool.get(first.index, first.generation).?.*);
    try testing.expectEqual(@as(u32, 10), pool.remove(first.index, first.generation).?);
    try testing.expect(pool.get(first.index, first.generation) == null);

    const second = try pool.insert(testing.allocator, 20);
    try testing.expectEqual(first.index, second.index);
    try testing.expect(first.generation != second.generation);
    try testing.expectEqual(@as(u32, 20), pool.get(second.index, second.generation).?.*);
}

test "resource generations never use zero" {
    try std.testing.expectEqual(@as(u32, 1), nextGeneration(std.math.maxInt(u32)));
}
