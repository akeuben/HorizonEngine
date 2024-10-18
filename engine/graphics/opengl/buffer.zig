const gl = @import("gl");

pub const OpenGLVertexBuffer = struct {
    gl_buffer: u32,
    pub fn init(comptime T: anytype, data: []const T) OpenGLVertexBuffer {
        var gl_buffer: u32 = 0;
        gl.genBuffers(1, &gl_buffer);

        const buffer = OpenGLVertexBuffer{ .gl_buffer = gl_buffer };
        buffer.set_data(T, data);

        return buffer;
    }

    pub inline fn bind(self: OpenGLVertexBuffer) void {
        gl.bindBuffer(gl.ARRAY_BUFFER, self.gl_buffer);
    }

    pub inline fn set_data(self: OpenGLVertexBuffer, comptime T: anytype, data: []const T) void {
        self.bind();
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(data.len * @sizeOf(T)), data.ptr, gl.STATIC_DRAW);
        self.unbind();
    }

    pub inline fn unbind(_: OpenGLVertexBuffer) void {
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    }
};
