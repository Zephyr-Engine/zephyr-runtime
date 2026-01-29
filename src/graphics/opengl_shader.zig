const std = @import("std");
const Map = std.StringHashMap(i32);
const layout = @import("layout.zig");
const ShaderHandle = @import("../asset/shader.zig").ShaderHandle;
const c = @import("../c.zig");
const gl = c.glad;

pub const ShaderError = error{
    VertexShaderCreationFailed,
    FragmentShaderCreationFailed,
    VertexShaderCompilationFailed,
    FragmentShaderCompilationFailed,
    ProgramCreationFailed,
    ProgramLinkingFailed,
    OpenGLError,
};

pub const Shader = struct {
    id: ShaderHandle,
    buffer_layout: layout.BufferLayout,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, vs_src: []const u8, fs_src: []const u8) !Shader {
        const vs_ptrs = [_][*c]const u8{
            @ptrCast(vs_src.ptr),
        };

        const vs: u32 = gl.glCreateShader(gl.GL_VERTEX_SHADER);
        if (vs == 0) {
            return ShaderError.VertexShaderCreationFailed;
        }
        errdefer gl.glDeleteShader(vs);

        gl.glShaderSource(vs, 1, &vs_ptrs, null);
        gl.glCompileShader(vs);

        var vs_success: i32 = 0;
        gl.glGetShaderiv(vs, gl.GL_COMPILE_STATUS, &vs_success);
        if (vs_success == 0) {
            var info_log: [512]u8 = undefined;
            gl.glGetShaderInfoLog(vs, 512, null, @ptrCast(&info_log));
            std.debug.print("Vertex shader compilation failed: {s}\n", .{info_log});
            return ShaderError.VertexShaderCompilationFailed;
        }

        const fs_ptrs = [_][*c]const u8{
            @ptrCast(fs_src.ptr),
        };

        const fs: u32 = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
        if (fs == 0) {
            return ShaderError.FragmentShaderCreationFailed;
        }
        errdefer gl.glDeleteShader(fs);

        gl.glShaderSource(fs, 1, &fs_ptrs, null);
        gl.glCompileShader(fs);

        var fs_success: i32 = 0;
        gl.glGetShaderiv(fs, gl.GL_COMPILE_STATUS, &fs_success);
        if (fs_success == 0) {
            var info_log: [512]u8 = undefined;
            gl.glGetShaderInfoLog(fs, 512, null, @ptrCast(&info_log));
            std.debug.print("Fragment shader compilation failed: {s}\n", .{info_log});
            return ShaderError.FragmentShaderCompilationFailed;
        }

        const program = gl.glCreateProgram();
        if (program == 0) {
            return ShaderError.ProgramCreationFailed;
        }
        errdefer gl.glDeleteProgram(program);

        gl.glAttachShader(program, vs);
        gl.glAttachShader(program, fs);
        gl.glLinkProgram(program);

        var link_success: i32 = 0;
        gl.glGetProgramiv(program, gl.GL_LINK_STATUS, &link_success);
        if (link_success == 0) {
            var info_log: [512]u8 = undefined;
            gl.glGetProgramInfoLog(program, 512, null, @ptrCast(&info_log));
            std.debug.print("Shader program linking failed: {s}\n", .{info_log});
            gl.glDeleteShader(vs);
            gl.glDeleteShader(fs);
            return ShaderError.ProgramLinkingFailed;
        }

        gl.glDeleteShader(vs);
        gl.glDeleteShader(fs);

        var count: i32 = 0;
        gl.glGetProgramiv(program, gl.GL_ACTIVE_ATTRIBUTES, &count);

        const AttributeInfo = struct {
            shader_type: layout.DataType,
            name: [256]u8,
            location: u32,
        };
        var attrs = try allocator.alloc(AttributeInfo, @intCast(count));
        defer allocator.free(attrs);

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

            const loc: i32 = gl.glGetAttribLocation(program, @ptrCast(&name));
            attrs[i] = .{
                .shader_type = shader_type,
                .name = name,
                .location = @intCast(loc),
            };
        }

        std.mem.sort(AttributeInfo, attrs, {}, struct {
            fn lessThan(_: void, a: AttributeInfo, b: AttributeInfo) bool {
                return a.location < b.location;
            }
        }.lessThan);

        var stride: u32 = 0;
        var bufferElements = try layout.BufferElements.initCapacity(allocator, @intCast(count));
        for (attrs) |attr| {
            const element = layout.BufferElement.new(attr.shader_type, stride, false, attr.name, attr.location);
            stride += element.size;
            try bufferElements.append(allocator, element);
        }

        return .{
            .id = program,
            .buffer_layout = layout.BufferLayout.new(bufferElements, stride),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Shader) void {
        self.buffer_layout.elements.deinit(self.allocator);
    }

    pub fn bind(self: Shader) void {
        gl.glUseProgram(self.id);
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
            .float, .comptime_float => {
                gl.glUniform1f(location, @as(f32, value));
            },
            .int, .comptime_int => |i| {
                if (comptime T == comptime_int) {
                    gl.glUniform1i(location, @as(i32, value));
                } else if (comptime i.signedness == .signed) {
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
                @compileError("Unsupported uniform type");
            },
        }
    }
};
