const OpenGLContext = @import("context.zig").OpenGLContext;
const OpenGLVertexBuffer = @import("buffer.zig").OpenGLVertexBuffer;
const OpenGLIndexBuffer = @import("buffer.zig").OpenGLIndexBuffer;
const OpenGLPipeline = @import("shader.zig").OpenGLPipeline;
const OpenGLRenderTarget = @import("target.zig").OpenGLRenderTarget;
const gl = @import("gl");
const types = @import("../type.zig");
const log = @import("../../utils/log.zig");

pub const OpenGLVertexRenderObject = struct {
    gl_array: u32,
    layout: types.BufferLayout,

    pub fn init(_: *const OpenGLContext, pipeline: *const OpenGLPipeline, vertex_buffer: *const OpenGLVertexBuffer) OpenGLVertexRenderObject {
        var gl_array: u32 = 0;
        gl.genVertexArrays(1, &gl_array);

        gl.bindVertexArray(gl_array);
        gl.useProgram(pipeline.program);
        gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer.gl_buffer);

        for (vertex_buffer.layout.?.elements, 0..) |element, i| {
            gl.enableVertexAttribArray(@intCast(i));
            gl.vertexAttribPointer(@intCast(i), @intCast(element.length), gl.FLOAT, gl.FALSE, @intCast(vertex_buffer.layout.?.size), @ptrFromInt(element.offset));
        }
        return .{
            .gl_array = gl_array,
            .layout = vertex_buffer.layout.?,
        };
    }

    pub fn draw(self: *const OpenGLVertexRenderObject, target: *const OpenGLRenderTarget) void {
        gl.bindFramebuffer(gl.FRAMEBUFFER, target.framebuffer);
        gl.bindVertexArray(self.gl_array);
        gl.drawArrays(gl.TRIANGLES, 0, @intCast(self.layout.length));
    }
};

pub const OpenGLIndexRenderObject = struct {
    gl_array: u32,
    layout: types.BufferLayout,
    count: u32,

    pub fn init(_: *const OpenGLContext, pipeline: *const OpenGLPipeline, vertex_buffer: *const OpenGLVertexBuffer, index_buffer: *const OpenGLIndexBuffer) OpenGLIndexRenderObject {
        var gl_array: u32 = 0;
        gl.genVertexArrays(1, &gl_array);

        gl.bindVertexArray(gl_array);
        gl.useProgram(pipeline.program);
        gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer.gl_buffer);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, index_buffer.gl_buffer);

        for (vertex_buffer.layout.?.elements, 0..) |element, i| {
            gl.enableVertexAttribArray(@intCast(i));
            gl.vertexAttribPointer(@intCast(i), @intCast(element.length), gl.FLOAT, gl.FALSE, @intCast(vertex_buffer.layout.?.size), @ptrFromInt(element.offset));
        }
        return .{
            .gl_array = gl_array,
            .layout = vertex_buffer.layout.?,
            .count = index_buffer.count,
        };
    }

    pub fn draw(self: *const OpenGLIndexRenderObject, _: *const OpenGLRenderTarget) void {
        gl.bindVertexArray(self.gl_array);
        gl.drawElements(gl.TRIANGLES, @intCast(self.count), gl.UNSIGNED_INT, null);
    }
};
