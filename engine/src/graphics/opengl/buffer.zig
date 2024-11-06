const std = @import("std");
const gl = @import("gl");
const types = @import("../type.zig");
const log = @import("../../utils/log.zig");

pub const OpenGLVertexBuffer = struct {
    gl_buffer: u32,
    layout: types.BufferLayout,

    pub fn init(comptime T: anytype, data: []const T) types.ShaderTypeError!OpenGLVertexBuffer {
        var gl_buffer: u32 = 0;
        gl.genBuffers(1, &gl_buffer);
        log.debug("Generated buffer {}", .{gl_buffer});

        // Get information on attribute types in T
        const layout = types.generate_layout(T, data) catch |e| {
            return e;
        };
        var buffer = OpenGLVertexBuffer{ .gl_buffer = gl_buffer, .layout = layout };
        buffer.set_data(T, data) catch |e| {
            return e;
        };

        return buffer;
    }

    pub inline fn set_data(self: *OpenGLVertexBuffer, comptime T: anytype, data: []const T) types.ShaderTypeError!void {
        gl.bindBuffer(gl.ARRAY_BUFFER, self.gl_buffer);
        std.heap.page_allocator.free(self.layout.elements);
        const layout = types.generate_layout(T, data) catch |e| {
            return e;
        };
        self.layout = layout;
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(data.len * self.layout.size), data.ptr, gl.STATIC_DRAW);
        log.debug("Buffer data loaded into buffer {} ", .{self.gl_buffer});
    }

    pub fn get_layout(self: OpenGLVertexBuffer) types.BufferLayout {
        return self.layout;
    }

    pub fn deinit(self: OpenGLVertexBuffer) void {
        gl.deleteBuffers(1, &self.gl_buffer);
    }
};

pub const OpenGLIndexBuffer = struct {
    gl_buffer: u32,
    count: u32,

    pub fn init(data: []const u32) types.ShaderTypeError!OpenGLIndexBuffer {
        var gl_buffer: u32 = 0;
        gl.genBuffers(1, &gl_buffer);
        log.debug("Generated buffer {} count: {}", .{ gl_buffer, data.len });

        var buffer = OpenGLIndexBuffer{
            .gl_buffer = gl_buffer,
            .count = @intCast(data.len),
        };
        buffer.set_data(data) catch |e| {
            return e;
        };

        return buffer;
    }

    pub inline fn set_data(self: *OpenGLIndexBuffer, data: []const u32) types.ShaderTypeError!void {
        self.count = @intCast(data.len);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.gl_buffer);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(data.len * @sizeOf(u32)), data.ptr, gl.STATIC_DRAW);
        log.debug("Buffer data loaded into buffer {} ", .{self.gl_buffer});
    }

    pub fn deinit(self: OpenGLIndexBuffer) void {
        gl.deleteBuffers(1, &self.gl_buffer);
    }
};
