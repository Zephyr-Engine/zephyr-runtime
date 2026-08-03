const ResourceHandle = @import("resource_handle.zig");

pub const Usage = packed struct(u8) {
    vertex: bool = false,
    index: bool = false,
    uniform: bool = false,
    storage: bool = false,
    transfer_dst: bool = false,
    _padding: u3 = 0,
};

pub const Desc = struct {
    size: usize,
    usage: Usage,
    initial_data: ?[]const u8 = null,
};

const Buffer = @This();
handle: ResourceHandle,
size: usize,
usage: Usage,
