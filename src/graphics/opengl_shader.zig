const std = @import("std");
const c = @import("../c.zig");
const gl = c.glad;

pub const Shader = struct {
    id: u32,

    pub fn init(vs_src: []const u8, fs_src: []const u8) Shader {
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

        return .{
            .id = program,
        };
    }

    pub fn bind(self: Shader) void {
        gl.glUseProgram(self.id);
    }

    pub fn setUniform(self: Shader, name: []const u8, value: anytype) void {
        const location = gl.glGetUniformLocation(self.id, @ptrCast(name.ptr));
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
