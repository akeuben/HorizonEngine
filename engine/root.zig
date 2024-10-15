const std = @import("std");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const gl = @import("zgl");

const context = @import("graphics/context.zig");
const api = @import("graphics/api.zig");
const w = @import("platform/window.zig");

pub fn testglfw() !u8 {
    const window = w.create_window();
    try api.set_api(.OPEN_GL);

    try window.use_gl();

    while (!window.should_close()) {
        window.update();
        window.set_width(700);
        try window.swap_buffers_gl();
    }

    return 0;
}
