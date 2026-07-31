const zcs = @import("zcs");

pub const Game = struct {
    components: []const type,
    update_schedule: zcs.Schedule.Spec,
};
