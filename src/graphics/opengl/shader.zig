const std = @import("std");
const Map = std.StringHashMap(i32);

const log = @import("../../core/log.zig");
const c = @import("../../c.zig");
const gl = c.glad;

pub const ShaderError = error{
    VertexShaderCreationFailed,
    FragmentShaderCreationFailed,
    VertexShaderCompilationFailed,
    FragmentShaderCompilationFailed,
    ProgramCreationFailed,
    ProgramLinkingFailed,
    OpenGLError,
    OutOfMemory,
};

pub const Shader = struct {
    id: u32,
    allocator: std.mem.Allocator,
    uniforms: Map,

    pub fn init(allocator: std.mem.Allocator, vs_src: []const u8, fs_src: []const u8) ShaderError!Shader {
        const vs: u32 = gl.glCreateShader(gl.GL_VERTEX_SHADER);
        if (vs == 0) {
            return ShaderError.VertexShaderCreationFailed;
        }
        errdefer gl.glDeleteShader(vs);

        const vs_ptr: [*c]const u8 = @ptrCast(vs_src.ptr);
        const vs_len: c_int = @intCast(vs_src.len);
        gl.glShaderSource(vs, 1, &vs_ptr, &vs_len);
        gl.glCompileShader(vs);

        var vs_success: i32 = 0;
        gl.glGetShaderiv(vs, gl.GL_COMPILE_STATUS, &vs_success);
        if (vs_success == 0) {
            var info_log: [512]u8 = [_]u8{0} ** 512;
            var info_log_len: c_int = 0;
            gl.glGetShaderInfoLog(vs, info_log.len, &info_log_len, @ptrCast(&info_log));
            const message = info_log[0..@intCast(@min(@max(info_log_len, 0), info_log.len))];
            log.err("vertex shader compilation failed: {s}", .{message});
            return ShaderError.VertexShaderCompilationFailed;
        }

        const fs: u32 = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
        if (fs == 0) {
            return ShaderError.FragmentShaderCreationFailed;
        }
        errdefer gl.glDeleteShader(fs);

        const fs_ptr: [*c]const u8 = @ptrCast(fs_src.ptr);
        const fs_len: c_int = @intCast(fs_src.len);
        gl.glShaderSource(fs, 1, &fs_ptr, &fs_len);
        gl.glCompileShader(fs);

        var fs_success: i32 = 0;
        gl.glGetShaderiv(fs, gl.GL_COMPILE_STATUS, &fs_success);
        if (fs_success == 0) {
            var info_log: [512]u8 = [_]u8{0} ** 512;
            var info_log_len: c_int = 0;
            gl.glGetShaderInfoLog(fs, info_log.len, &info_log_len, @ptrCast(&info_log));
            const message = info_log[0..@intCast(@min(@max(info_log_len, 0), info_log.len))];
            log.err("fragment shader compilation failed: {s}", .{message});
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
            var info_log: [512]u8 = [_]u8{0} ** 512;
            var info_log_len: c_int = 0;
            gl.glGetProgramInfoLog(program, info_log.len, &info_log_len, @ptrCast(&info_log));
            const message = info_log[0..@intCast(@min(@max(info_log_len, 0), info_log.len))];
            log.err("shader program linking failed: {s}", .{message});
            return ShaderError.ProgramLinkingFailed;
        }

        gl.glDeleteShader(vs);
        gl.glDeleteShader(fs);

        return .{
            .id = program,
            .allocator = allocator,
            .uniforms = try getUniformLocations(program, allocator),
        };
    }

    pub fn deinit(self: *Shader) void {
        var it = self.uniforms.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.uniforms.deinit();
        gl.glDeleteProgram(self.id);
        self.id = 0;
    }

    fn getUniformLocations(self: u32, allocator: std.mem.Allocator) ShaderError!Map {
        var count: i32 = 0;
        gl.glGetProgramiv(self, gl.GL_ACTIVE_UNIFORMS, &count);

        const uniform_count: u32 = @intCast(count);
        var map = Map.init(allocator);
        errdefer {
            var it = map.keyIterator();
            while (it.next()) |key| {
                allocator.free(key.*);
            }
            map.deinit();
        }
        try map.ensureTotalCapacity(uniform_count);

        var name_buf: [256]u8 = undefined;
        for (0..uniform_count) |i| {
            var length: i32 = 0;
            var size: i32 = 0;
            var ty: u32 = 0;

            gl.glGetActiveUniform(
                self,
                @intCast(i),
                name_buf.len,
                &length,
                &size,
                &ty,
                @ptrCast(&name_buf),
            );

            const loc = gl.glGetUniformLocation(
                self,
                @ptrCast(&name_buf),
            );
            const name_slice = name_buf[0..@intCast(length)];
            const owned_name = try allocator.dupe(u8, name_slice);
            map.putAssumeCapacity(owned_name, loc);
        }

        return map;
    }

    pub fn uniformLocation(self: *const Shader, name: []const u8) ?i32 {
        return self.uniforms.get(name);
    }

    pub fn setUniformFromLocation(_: *const Shader, location: i32, value: anytype) void {
        const T = comptime @TypeOf(value);
        switch (comptime @typeInfo(T)) {
            .float, .comptime_float => {
                gl.glUniform1f(location, @as(f32, value));
            },
            .comptime_int => {
                gl.glUniform1i(location, @as(i32, value));
            },
            .int => |i| {
                if (comptime i.signedness == .signed) {
                    gl.glUniform1i(location, @as(i32, value));
                } else {
                    gl.glUniform1i(location, @as(i32, @intCast(value)));
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

    pub fn setUniform(self: *const Shader, name: []const u8, value: anytype) void {
        const location = self.uniformLocation(name) orelse return;
        self.setUniformFromLocation(location, value);
    }

    pub fn bind(self: Shader) void {
        gl.glUseProgram(self.id);
    }

    pub fn unbind(self: Shader) void {
        _ = self;
        gl.glUseProgram(0);
    }
};
