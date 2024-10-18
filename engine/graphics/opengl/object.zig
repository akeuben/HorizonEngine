const log = @import("../../utils/log.zig");
const std = @import("std");
const buffer = @import("buffer.zig");
const shader = @import("shader.zig");
const gl = @import("gl");
const zm = @import("zm");

pub const OpenGLRenderObject = struct {
    gl_array: u32,
    vertex_buffer: *const buffer.OpenGLVertexBuffer,
    pipeline: *const shader.OpenGLPipeline,

    pub fn init(vertex_buffer: *const buffer.OpenGLVertexBuffer, pipeline: *const shader.OpenGLPipeline) OpenGLRenderObject {
        var gl_array: u32 = 0;
        gl.genVertexArrays(1, &gl_array);

        const object = OpenGLRenderObject{
            .gl_array = gl_array,
            .pipeline = pipeline,
            .vertex_buffer = vertex_buffer,
        };

        object.bind();
        vertex_buffer.bind();
        for (vertex_buffer.layout.elements, 0..) |element, i| {
            gl.vertexAttribPointer(@intCast(i), @intCast(element.length), gl.FLOAT, gl.FALSE, @intCast(vertex_buffer.layout.size), @ptrFromInt(element.offset));
            gl.enableVertexAttribArray(@intCast(i));
        }

        return object;
    }

    pub fn bind(self: OpenGLRenderObject) void {
        gl.bindVertexArray(self.gl_array);
        self.pipeline.bind();
    }
    pub fn render(self: OpenGLRenderObject) void {
        self.bind();
        gl.drawArrays(gl.TRIANGLES, 0, @intCast(self.vertex_buffer.layout.length));
    }
    pub fn unbind(_: OpenGLRenderObject) void {
        gl.bindVertexArray(0);
    }
};
