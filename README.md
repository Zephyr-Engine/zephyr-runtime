# Zephyr Runtime

A game engine written in Zig for learning, currently uses glfw for window management and OpenGL 4.6 as it's renderer.

## Building

```zig
zig fetch --save git+https://github.com/tiawl/glfw.zig.git
zig fetch --save git+https://github.com/jackparsonss/zig.glad.git

zig build check // this will generate a zig cache for lsp autocomplete

// run tests
zig build test --summary all
```
