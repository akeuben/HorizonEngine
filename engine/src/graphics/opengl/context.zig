const Window = @import("../../platform/window.zig").Window;
const gl = @import("gl");
const log = @import("../../utils/log.zig");
const OpenGLVertexBuffer = @import("buffer.zig").OpenGLVertexBuffer;
const OpenGLPipeline = @import("shader.zig").OpenGLPipeline;
const OpenGLRenderTarget = @import("target.zig").OpenGLRenderTarget;

fn gl_error_callback(_: gl.GLenum, _: gl.GLenum, id: gl.GLuint, severity: gl.GLenum, _: gl.GLsizei, message: [*:0]const u8, _: ?*anyopaque) callconv(.C) void {
    log.debug("A GL error occurred.", .{});
    return switch (severity) {
        gl.DEBUG_SEVERITY_HIGH => log.err("GL {}: {s}", .{ id, message }),
        gl.DEBUG_SEVERITY_MEDIUM => log.err("GL {}: {s}", .{ id, message }),
        gl.DEBUG_SEVERITY_LOW => log.info("GL {}: {s}", .{ id, message }),
        gl.DEBUG_SEVERITY_NOTIFICATION => log.debug("GL {}: {s}", .{ id, message }),
        else => unreachable,
    };
}

pub const OpenGLContext = struct {
    target: OpenGLRenderTarget,

    pub fn init() OpenGLContext {
        const ctx = OpenGLContext{
            .target = .{
                // The default framebuffer defined by OpenGL
                .framebuffer = 0,
            },
        };

        return ctx;
    }

    pub fn deinit(_: OpenGLContext) void {}

    pub fn load(self: *OpenGLContext, window: *const Window) void {
        window.set_current_context(.{ .OPEN_GL = self.* });

        gl.load(window.*, Window.get_gl_loader) catch {
            log.fatal("Failed to load gl", .{});
        };
        gl.GL_ARB_gl_spirv.load(window.*, Window.get_gl_loader) catch {
            log.fatal("Fauled to load gl extension GL_ARB_gl_spirv. Does your system support it?", .{});
        };

        gl.enable(gl.FRAMEBUFFER_SRGB);
        gl.enable(gl.DEBUG_OUTPUT);
        gl.debugMessageCallback(gl_error_callback, null);
        log.debug("Enabled gl debug callback", .{});
    }

    pub fn notify_resized(_: *OpenGLContext, new_size: @Vector(2, i32)) void {
        gl.viewport(0, 0, new_size[0], new_size[1]);
    }

    pub fn get_target(self: *OpenGLContext) *OpenGLRenderTarget {
        log.debug("GL MODE", .{});
        return &self.target;
    }
};
