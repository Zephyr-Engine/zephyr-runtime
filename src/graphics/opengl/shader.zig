const std = @import("std");
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
};

pub const Shader = struct {
    id: u32,

    pub fn init(vs_src: [*c]const u8, fs_src: [*c]const u8) ShaderError!Shader {
        const vs: u32 = gl.glCreateShader(gl.GL_VERTEX_SHADER);
        if (vs == 0) {
            return ShaderError.VertexShaderCreationFailed;
        }
        errdefer gl.glDeleteShader(vs);

        gl.glShaderSource(vs, 1, &vs_src, null);
        gl.glCompileShader(vs);

        var vs_success: i32 = 0;
        gl.glGetShaderiv(vs, gl.GL_COMPILE_STATUS, &vs_success);
        if (vs_success == 0) {
            var info_log: [512]u8 = undefined;
            gl.glGetShaderInfoLog(vs, 512, null, @ptrCast(&info_log));
            std.debug.print("Vertex shader compilation failed: {s}\n", .{info_log});
            return ShaderError.VertexShaderCompilationFailed;
        }

        const fs: u32 = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
        if (fs == 0) {
            return ShaderError.FragmentShaderCreationFailed;
        }
        errdefer gl.glDeleteShader(fs);

        gl.glShaderSource(fs, 1, &fs_src, null);
        gl.glCompileShader(fs);

        var fs_success: i32 = 0;
        gl.glGetShaderiv(fs, gl.GL_COMPILE_STATUS, &fs_success);
        if (fs_success == 0) {
            var info_log: [512]u8 = undefined;
            gl.glGetShaderInfoLog(vs, 512, null, @ptrCast(&info_log));
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
            return ShaderError.ProgramLinkingFailed;
        }

        gl.glDeleteShader(vs);
        gl.glDeleteShader(fs);

        return .{
            .id = program,
        };
    }

    pub fn bind(self: Shader) void {
        gl.glUseProgram(self.id);
    }

    pub fn unbind(self: Shader) void {
        _ = self;
        gl.glUseProgram(0);
    }
};
