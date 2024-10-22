const Window = @import("../../platform/window.zig").Window;
const gl = @import("gl");
const log = @import("../../utils/log.zig");

fn gl_error_callback(_: gl.GLenum, _: gl.GLenum, id: gl.GLuint, severity: gl.GLenum, _: gl.GLsizei, message: [*:0]const u8, _: ?*anyopaque) callconv(.C) void {
    return switch (severity) {
        gl.DEBUG_SEVERITY_HIGH => log.err("GL {}: {s}", .{ id, message }),
        gl.DEBUG_SEVERITY_MEDIUM => log.err("GL {}: {s}", .{ id, message }),
        gl.DEBUG_SEVERITY_LOW => log.info("GL {}: {s}", .{ id, message }),
        gl.DEBUG_SEVERITY_NOTIFICATION => log.debug("GL {}: {s}", .{ id, message }),
        else => unreachable,
    };
}

pub const OpenGLContext = struct {
    pub fn init() OpenGLContext {
        const ctx = .{};

        return ctx;
    }

    pub fn deinit(_: OpenGLContext) void {}

    pub fn load(self: *OpenGLContext, window: *const Window) void {
        window.set_current_context(.{ .OPEN_GL = self.* });

        gl.load(window.*, Window.get_gl_loader) catch {
            log.fatal("Failed to load gl extensions", .{});
        };

        gl.enable(gl.DEBUG_OUTPUT);
        gl.debugMessageCallback(gl_error_callback, null);
    }

    pub fn clear(_: OpenGLContext) void {
        gl.clearColor(0.02, 0.55, 0.40, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    }
};
