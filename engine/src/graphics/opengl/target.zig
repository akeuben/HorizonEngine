const std = @import("std");
const context = @import("context.zig");
const OpenGLPipeline = @import("shader.zig").OpenGLPipeline;
const OpenGLVertexBuffer = @import("buffer.zig").OpenGLVertexBuffer;
const OpenGLRenderObject = @import("object.zig").OpenGLRenderObject;
const RenderObject = @import("../object.zig").RenderObject;
const RenderTarget = @import("../target.zig").RenderTarget;
const gl = @import("gl");
const log = @import("../../utils/log.zig");

pub const OpenGLRenderTarget = struct {
    framebuffer: u32,

    pub fn init(_: *const context.OpenGLContext) OpenGLRenderTarget {
        var framebuffer: u32 = 0;
        gl.genFramebuffers(1, @ptrCast(&framebuffer));

        return .{
            .framebuffer = framebuffer,
        };
    }

    pub fn start(_: *const OpenGLRenderTarget, _: *const context.OpenGLContext) void {
        gl.clearColor(0, 0, 0, 1);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    }

    pub fn render(self: *const OpenGLRenderTarget, ctx: *const context.OpenGLContext, object: *const RenderObject) void {
        gl.bindFramebuffer(gl.FRAMEBUFFER, self.framebuffer);
        object.draw(&ctx.context(), &self.target());
    }

    pub fn end(_: *const OpenGLRenderTarget, _: *const context.OpenGLContext) void {}
    pub fn submit(_: *const OpenGLRenderTarget, _: *const context.OpenGLContext) void {}

    pub fn deinit(self: OpenGLRenderTarget) void {
        gl.deleteFramebuffers(1, @ptrCast(&self.framebuffer));
    }

    pub fn target(self: OpenGLRenderTarget) RenderTarget {
        return .{
            .OPEN_GL = self,
        };
    }
};
