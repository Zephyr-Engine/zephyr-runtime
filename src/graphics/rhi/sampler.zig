const zimp = @import("zimp");

const ResourceHandle = @import("resource_handle.zig");

pub const Filter = enum {
    nearest,
    linear,
};

pub const MipFilter = enum {
    none,
    nearest,
    linear,
};

pub const AddressMode = enum {
    repeat,
    clamp_to_edge,
    mirrored_repeat,
};

pub const Desc = struct {
    min_filter: Filter = .linear,
    mag_filter: Filter = .linear,
    mip_filter: MipFilter = .linear,
    address_u: AddressMode = .repeat,
    address_v: AddressMode = .repeat,
    max_anisotropy: f32 = 8,

    pub fn fromTextureSlotEntry(entry: zimp.TextureSlotEntry) Desc {
        return .{
            .min_filter = switch (entry.sampler.min_filter) {
                .nearest => .nearest,
                .linear => .linear,
            },
            .mag_filter = switch (entry.sampler.mag_filter) {
                .nearest => .nearest,
                .linear => .linear,
            },
            .mip_filter = switch (entry.sampler.mip_filter) {
                .nearest => .nearest,
                .linear => .linear,
                .none => .none,
            },
            .address_u = switch (entry.sampler.wrap_s) {
                .clamp_to_edge => .clamp_to_edge,
                .mirrored_repeat => .mirrored_repeat,
                .repeat => .repeat,
            },
            .address_v = switch (entry.sampler.wrap_t) {
                .clamp_to_edge => .clamp_to_edge,
                .mirrored_repeat => .mirrored_repeat,
                .repeat => .repeat,
            },
            .max_anisotropy = entry.sampler.max_anisotropy,
        };
    }
};

const Sampler = @This();
handle: ResourceHandle,
