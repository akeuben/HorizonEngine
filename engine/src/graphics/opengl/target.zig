const std = @import("std");
const context = @import("context.zig");
const OpenGLPipeline = @import("shader.zig").OpenGLPipeline;
const OpenGLVertexBuffer = @import("buffer.zig").OpenGLVertexBuffer;
const OpenGLRenderObject = @import("object.zig").OpenGLRenderObject;
const gl = @import("gl");
const log = @import("../../utils/log.zig");

pub const OpenGLRenderTarget = struct {
    framebuffer: u32,

    pub fn init(_: *const context.OpenGLContext, allocator: std.mem.Allocator) *OpenGLRenderTarget {
        var framebuffer: u32 = 0;
        gl.genFramebuffers(1, @ptrCast(&framebuffer));

        const target = try allocator.create(OpenGLRenderTarget);
        target.framebuffer = framebuffer;
        return target;
    }

    pub fn start(_: *const OpenGLRenderTarget, _: *const context.OpenGLContext) void {
        gl.clearColor(0, 0, 0, 1);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    }

    pub fn render(self: *const OpenGLRenderTarget, _: *const context.OpenGLContext, object: *const OpenGLRenderObject) void {
        gl.bindFramebuffer(gl.FRAMEBUFFER, self.framebuffer);
        gl.bindVertexArray(object.gl_array);
        if (object.count == 0) {
            gl.drawArrays(gl.TRIANGLES, 0, @intCast(object.layout.length));
        } else {
            gl.drawElements(gl.TRIANGLES, @intCast(object.count), gl.UNSIGNED_INT, null);
        }
        gl.drawArrays(gl.TRIANGLES, 0, @intCast(object.layout.length));
    }

    pub fn end(_: *const OpenGLRenderTarget, _: *const context.OpenGLContext) void {}
    pub fn submit(_: *const OpenGLRenderTarget, _: *const context.OpenGLContext) void {}

    pub fn deinit(self: OpenGLRenderTarget) void {
        gl.deleteFramebuffers(1, @ptrCast(&self.framebuffer));
    }
};
