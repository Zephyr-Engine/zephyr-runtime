const ResourceHandle = @This();

owner: *const anyopaque,
index: u32,
generation: u32,

pub fn belongsTo(self: ResourceHandle, owner: *const anyopaque) bool {
    return self.owner == owner;
}

const testing = @import("std").testing;

test "belongsTo compares owner pointer identity" {
    var owner_a: u32 = 0;
    var owner_b: u32 = 0;

    const handle = ResourceHandle{ .owner = &owner_a, .index = 1, .generation = 1 };

    try testing.expect(handle.belongsTo(&owner_a));
    try testing.expect(!handle.belongsTo(&owner_b));
}
