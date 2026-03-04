const std = @import("std");
const c = @import("c.zig");
const glfw = c.glfw;
pub const gl = c.glad;

pub const Window = @import("core/window.zig").Window;
pub const Input = @import("core/input.zig").InputManager;
pub const Shader = @import("graphics/opengl/shader.zig").Shader;
pub const Application = @import("core/application.zig").Application;
pub const VertexArray = @import("graphics/opengl/vertex_array.zig").VertexArray;

pub const recommended_std_options: std.Options = .{
    .logFn = @import("core/log.zig").log,
};
