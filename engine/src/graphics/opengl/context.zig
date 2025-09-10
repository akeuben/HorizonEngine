const std = @import("std");
const Window = @import("../../platform/window.zig").Window;
const gl = @import("gl");
const log = @import("../../utils/log.zig");
const OpenGLVertexBuffer = @import("buffer.zig").OpenGLVertexBuffer;
const OpenGLPipeline = @import("shader.zig").OpenGLPipeline;
const OpenGLRenderTarget = @import("target.zig").OpenGLRenderTarget;
const Context = @import("../context.zig").Context;
const ContextCreationOptions = @import("../context.zig").ContextCreationOptions;
const event = @import("../../event/event.zig");

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
    allocator: std.mem.Allocator,
    event_node: event.EventNode,

    creation_options: ContextCreationOptions,

    pub fn init(allocator: std.mem.Allocator, options: ContextCreationOptions) *OpenGLContext {
        const ctx = allocator.create(OpenGLContext) catch unreachable;
        ctx.target = .{
            // The default framebuffer defined by OpenGL
            .framebuffer = 0,
            .ctx = ctx,
        };
        ctx.allocator = allocator;
        ctx.creation_options = options;

        ctx.event_node = event.EventNode.init(allocator, ctx, &.{
            event.init_handler_custom(OpenGLContext, event.window.WindowResizeEvent, &on_window_resized),
        });

        return ctx;
    }

    pub fn load(self: *OpenGLContext, window: *const Window) void {
        window.set_current_context(.{ .OPEN_GL = self });

        gl.load(window.*, Window.get_gl_loader) catch {
            log.fatal("Failed to load gl", .{});
        };
        gl.GL_ARB_gl_spirv.load(window.*, Window.get_gl_loader) catch {
            log.fatal("Fauled to load gl extension GL_ARB_gl_spirv. Does your system support it?", .{});
        };

        gl.enable(gl.FRAMEBUFFER_SRGB);
        gl.enable(gl.DEBUG_OUTPUT);
        if (self.creation_options.use_debug) gl.debugMessageCallback(gl_error_callback, null);
        log.debug("Enabled gl debug callback", .{});
        gl.enable(gl.DEPTH_TEST);
        gl.enable(gl.CULL_FACE);
        gl.cullFace(gl.BACK);
        gl.frontFace(gl.CCW);
    }

    fn on_window_resized(_: ?*OpenGLContext, e: *const event.window.WindowResizeEvent, _: event.EventResult) event.EventResult {
        gl.viewport(0, 0, e.width, e.height);

        return .HANDLED;
    }

    pub fn get_event_node(self: *OpenGLContext) ?*event.EventNode {
        return &self.event_node;
    }

    pub fn get_target(self: *OpenGLContext) OpenGLRenderTarget {
        return self.target;
    }

    pub fn context(self: *OpenGLContext) Context {
        return .{
            .OPEN_GL = self,
        };
    }

    pub fn deinit(self: *OpenGLContext) void {
        self.allocator.destroy(self);
    }
};
