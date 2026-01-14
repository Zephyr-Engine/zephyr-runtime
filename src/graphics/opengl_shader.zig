const std = @import("std");
const Map = std.StringHashMap(i32);
const layout = @import("layout.zig");
const ShaderHandle = @import("../asset/shader.zig").ShaderHandle;
const c = @import("../c.zig");
const gl = c.glad;

pub const Shader = struct {
    id: ShaderHandle,
    buffer_layout: layout.BufferLayout,

    pub fn init(allocator: std.mem.Allocator, vs_src: []const u8, fs_src: []const u8) !Shader {
        const vs_ptrs = [_][*c]const u8{
            @ptrCast(vs_src.ptr),
        };

        const vs: u32 = gl.glCreateShader(gl.GL_VERTEX_SHADER);
        gl.glShaderSource(vs, 1, &vs_ptrs, null);
        gl.glCompileShader(vs);

        const fs_ptrs = [_][*c]const u8{
            @ptrCast(fs_src.ptr),
        };

        const fs: u32 = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
        gl.glShaderSource(fs, 1, &fs_ptrs, null);
        gl.glCompileShader(fs);

        const program = gl.glCreateProgram();
        gl.glAttachShader(program, vs);
        gl.glAttachShader(program, fs);
        gl.glLinkProgram(program);

        gl.glDeleteShader(vs);
        gl.glDeleteShader(fs);

        var count: i32 = 0;
        gl.glGetProgramiv(program, gl.GL_ACTIVE_ATTRIBUTES, &count);

        var stride: u32 = 0;
        var bufferElements = try layout.BufferElements.initCapacity(allocator, @intCast(count));
        for (0..@intCast(count)) |i| {
            var length: i32 = 0;
            var size: i32 = 0;
            var ty: u32 = 0;
            var name: [256]u8 = undefined;

            gl.glGetActiveAttrib(program, @intCast(i), name.len, &length, &size, &ty, @ptrCast(&name));

            const shader_type: layout.DataType = switch (ty) {
                gl.GL_FLOAT => .Float,
                gl.GL_FLOAT_VEC2 => .Float2,
                gl.GL_FLOAT_VEC3 => .Float3,
                gl.GL_FLOAT_VEC4 => .Float4,
                gl.GL_INT => .Int,
                gl.GL_INT_VEC2 => .Int2,
                gl.GL_INT_VEC3 => .Int3,
                gl.GL_INT_VEC4 => .Int4,
                gl.GL_BOOL => .Bool,
                gl.GL_FLOAT_MAT3 => .Mat3,
                gl.GL_FLOAT_MAT4 => .Mat4,
                else => .Float,
            };

            const element = layout.BufferElement.new(shader_type, stride, false, name);
            stride += element.size;
            try bufferElements.append(allocator, element);
        }

        return .{
            .id = program,
            .buffer_layout = layout.BufferLayout.new(bufferElements, stride),
        };
    }

    pub fn deinit(self: *Shader, allocator: std.mem.Allocator) void {
        self.buffer_layout.elements.deinit(allocator);
    }

    pub fn bind(self: Shader) void {
        gl.glUseProgram(self.id);
    }

    pub fn getUniformLocation(self: Shader, name: [256]u8) i32 {
        return gl.glGetUniformLocation(self.id, @ptrCast(&name));
    }

    const locations = struct {
        name: *const []u8,
        location: i32,
    };
    pub fn getUniformLocations(self: Shader, allocator: std.mem.Allocator) !Map {
        var count: i32 = 0;
        gl.glGetProgramiv(self.id, gl.GL_ACTIVE_UNIFORMS, &count);

        var map = Map.init(allocator);
        try map.ensureTotalCapacity(@intCast(count));

        for (0..@intCast(count)) |i| {
            var length: i32 = 0;
            var size: i32 = 0;
            var ty: u32 = 0;
            var name: [256]u8 = undefined;
            gl.glGetActiveUniform(self.id, @intCast(i), 257, &length, &size, &ty, @ptrCast(&name));
            const loc = gl.glGetUniformLocation(self.id, @ptrCast(&name));

            const name_slice = name[0..@intCast(length)];
            const owned_name = try allocator.dupe(u8, name_slice);
            try map.put(owned_name, loc);
        }

        return map;
    }

    pub fn setUniform(self: Shader, location: i32, value: anytype) void {
        _ = self;
        const T = comptime @TypeOf(value);
        switch (comptime @typeInfo(T)) {
            .float => {
                gl.glUniform1f(location, @as(f32, value));
            },
            .int => |i| {
                if (comptime i.signedness == .signed) {
                    gl.glUniform1i(location, @as(i32, value));
                } else {
                    gl.glUniform1ui(location, @as(u32, value));
                }
            },
            .@"struct" => {
                if (comptime @hasField(T, "x") and @hasField(T, "y") and !@hasField(T, "z")) {
                    gl.glUniform2f(location, value.x, value.y);
                } else if (comptime @hasField(T, "x") and @hasField(T, "y") and @hasField(T, "z") and !@hasField(T, "w")) {
                    gl.glUniform3f(location, value.x, value.y, value.z);
                } else if (comptime @hasField(T, "x") and @hasField(T, "y") and @hasField(T, "z") and @hasField(T, "w")) {
                    gl.glUniform4f(location, value.x, value.y, value.z, value.w);
                } else if (comptime @hasField(T, "fields")) {
                    if (comptime @TypeOf(value.fields) == [3][3]f32) {
                        gl.glUniformMatrix3fv(location, 1, gl.GL_FALSE, @ptrCast(&value.fields));
                    } else if (comptime @TypeOf(value.fields) == [4][4]f32) {
                        gl.glUniformMatrix4fv(location, 1, gl.GL_FALSE, @ptrCast(&value.fields));
                    } else {
                        @compileError("Unsupported matrix type");
                    }
                } else {
                    @compileError("Unsupported struct uniform type");
                }
            },
            else => {
                @compileError("Unsupported struct uniform type");
            },
        }
    }
};
