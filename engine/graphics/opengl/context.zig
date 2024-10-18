const Window = @import("../../platform/window.zig").Window;
const gl = @import("gl");
const log = @import("../../utils/log.zig");

pub const OpenGLContext = struct {
    pub fn init(_: OpenGLContext, window: Window) void {
        gl.load(window, Window.get_gl_loader) catch {
            log.fatal("Failed to load gl extensions", .{});
        };
    }

    pub fn clear(_: OpenGLContext) void {
        gl.clearColor(0.02, 0.55, 0.40, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    }
};
