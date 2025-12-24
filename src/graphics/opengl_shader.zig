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
};
