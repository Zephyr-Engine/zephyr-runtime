const render_state = @import("../render_state.zig");

pub const ShaderCode = union(enum) {
    glsl: []const u8,
    spirv: []const u32,
};

pub const GraphicsPipelineDesc = struct {
    vertex: ShaderCode,
    fragment: ShaderCode,
    fixed_state: render_state.FixedState,
};

pub const UniformLocation = struct {
    slot: u32,
};

pub const UniformValue = union(enum) {
    float: f32,
    int: i32,
    vec2: [2]f32,
    vec3: [3]f32,
    vec4: [4]f32,
    mat3: [3][3]f32,
    mat4: [4][4]f32,
};

const GraphicsPipeline = @This();

impl: *anyopaque,
vtable: *const VTable,
sort_key: u64,

pub const VTable = struct {
    destroy: *const fn (impl: *anyopaque) void,
    bind: *const fn (impl: *const anyopaque) void,
    uniformLocation: *const fn (impl: *const anyopaque, name: []const u8) ?UniformLocation,
    setUniformFromLocation: *const fn (impl: *const anyopaque, location: UniformLocation, value: UniformValue) void,
};

pub fn deinit(self: *GraphicsPipeline) void {
    self.vtable.destroy(self.impl);
    self.* = undefined;
}

pub fn bind(self: *const GraphicsPipeline) void {
    self.vtable.bind(self.impl);
}

pub fn uniformLocation(self: *const GraphicsPipeline, name: []const u8) ?UniformLocation {
    return self.vtable.uniformLocation(self.impl, name);
}

pub fn setUniformFromLocation(self: *const GraphicsPipeline, location: UniformLocation, value: UniformValue) void {
    self.vtable.setUniformFromLocation(self.impl, location, value);
}

pub fn setUniform(self: *const GraphicsPipeline, name: []const u8, value: UniformValue) void {
    const location = self.uniformLocation(name) orelse return;
    self.setUniformFromLocation(location, value);
}
