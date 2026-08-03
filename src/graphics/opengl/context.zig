const c = @import("../../c.zig");
const glfw = c.glfw;
const gl = c.glad;

pub fn configure(msaa_samples: u32) void {
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);
    if (msaa_samples > 1) {
        glfw.glfwWindowHint(glfw.GLFW_SAMPLES, @intCast(msaa_samples));
    }
}

pub fn initialize(window: c.Window, msaa_samples: u32) !void {
    glfw.glfwMakeContextCurrent(window);
    glfw.glfwSwapInterval(1);
    const loader: gl.GLADloadproc = @ptrCast(&glfw.glfwGetProcAddress);
    if (gl.gladLoadGLLoader(loader) == 0) {
        return error.ContextLoadFailed;
    }

    if (msaa_samples > 1) {
        gl.glEnable(gl.GL_MULTISAMPLE);
    }
}
