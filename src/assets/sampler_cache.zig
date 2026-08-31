const std = @import("std");

const Sampler = @import("../graphics/rhi/sampler.zig");
const Device = @import("../graphics/rhi/device.zig");

const SamplerCache = @This();

pub const Key = struct {
    min_filter: Sampler.Filter,
    mag_filter: Sampler.Filter,
    mip_filter: Sampler.MipFilter,
    address_u: Sampler.AddressMode,
    address_v: Sampler.AddressMode,
    max_anisotropy_bits: u32,
};

allocator: std.mem.Allocator,
values: std.AutoHashMapUnmanaged(Key, Sampler) = .empty,

pub fn keyFor(desc: Sampler.Desc) Key {
    return .{
        .min_filter = desc.min_filter,
        .mag_filter = desc.mag_filter,
        .mip_filter = desc.mip_filter,
        .address_u = desc.address_u,
        .address_v = desc.address_v,
        .max_anisotropy_bits = @bitCast(desc.max_anisotropy),
    };
}

pub fn get(self: *SamplerCache, device: *Device, desc: Sampler.Desc) !Sampler {
    const result = try self.values.getOrPut(self.allocator, keyFor(desc));
    if (!result.found_existing) {
        result.value_ptr.* = try device.createSampler(desc);
    }

    return result.value_ptr.*;
}

pub fn deinit(self: *SamplerCache, device: *Device) void {
    var values = self.values.valueIterator();
    while (values.next()) |value| {
        device.destroySampler(value);
    }
    self.values.deinit(self.allocator);
}
