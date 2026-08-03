const ResourceHandle = @import("resource_handle.zig");

pub const Filter = enum { nearest, linear };
pub const MipFilter = enum { none, nearest, linear };
pub const AddressMode = enum { repeat, clamp_to_edge };

pub const Desc = struct {
    min_filter: Filter = .linear,
    mag_filter: Filter = .linear,
    mip_filter: MipFilter = .linear,
    address_u: AddressMode = .repeat,
    address_v: AddressMode = .repeat,
    max_anisotropy: f32 = 8,
};

const Sampler = @This();
handle: ResourceHandle,
