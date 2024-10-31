const OpenGLContext = @import("context.zig").OpenGLContext;
const OpenGLVertexBuffer = @import("buffer.zig").OpenGLVertexBuffer;
const OpenGLPipeline = @import("shader.zig").OpenGLPipeline;
const gl = @import("gl");
const types = @import("../type.zig");

pub const OpenGLRenderObject = struct {
    gl_array: u32,
    layout: types.BufferLayout,

    pub fn init(_: *const OpenGLContext, buffer: *const OpenGLVertexBuffer, pipeline: *const OpenGLPipeline) OpenGLRenderObject {
        var gl_array: u32 = 0;
        gl.genVertexArrays(1, &gl_array);

        gl.bindVertexArray(gl_array);
        gl.useProgram(pipeline.program);
        gl.bindBuffer(gl.ARRAY_BUFFER, buffer.gl_buffer);

        for (buffer.layout.elements, 0..) |element, i| {
            gl.enableVertexAttribArray(@intCast(i));
            gl.vertexAttribPointer(@intCast(i), @intCast(element.length), gl.FLOAT, gl.FALSE, @intCast(buffer.layout.size), @ptrFromInt(element.offset));
        }
        return .{
            .gl_array = gl_array,
            .layout = buffer.layout,
        };
    }
};
