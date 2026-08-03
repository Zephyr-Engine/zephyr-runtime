const ResourceHandle = @This();

owner: *const anyopaque,
index: u32,
generation: u32,

pub fn belongsTo(self: ResourceHandle, owner: *const anyopaque) bool {
    return self.owner == owner;
}
