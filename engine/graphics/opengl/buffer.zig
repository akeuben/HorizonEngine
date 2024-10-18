const std = @import("std");
const gl = @import("gl");
const types = @import("../type.zig");

fn generate_layout(comptime T: type, data: []const T) types.ShaderTypeError!types.BufferLayout {
    const len = comptime std.meta.fields(T).len;
    var elements = std.heap.page_allocator.alloc(types.BufferLayoutElement, len) catch {
        return types.ShaderTypeError.OutOfMemory;
    };

    inline for (comptime std.meta.fields(T), 0..) |field, i| {
        const attribute_descriptor = types.resolve_shader_type_info(field.type) catch {
            return types.ShaderTypeError.InvalidShaderType;
        };
        const element: types.BufferLayoutElement = .{
            .size = attribute_descriptor.size,
            .length = attribute_descriptor.length,
            .offset = @offsetOf(T, field.name),
        };
        elements[i] = element;
    }

    return types.BufferLayout{
        .size = @sizeOf(T),
        .length = data.len,
        .elements = elements,
    };
}

pub const OpenGLVertexBuffer = struct {
    gl_buffer: u32,
    layout: types.BufferLayout,

    pub fn init(comptime T: anytype, data: []const T) types.ShaderTypeError!OpenGLVertexBuffer {
        var gl_buffer: u32 = 0;
        gl.genBuffers(1, &gl_buffer);

        // Get information on attribute types in T
        const layout = generate_layout(T, data) catch |e| {
            return e;
        };
        var buffer = OpenGLVertexBuffer{ .gl_buffer = gl_buffer, .layout = layout };
        buffer.set_data(T, data) catch |e| {
            return e;
        };

        return buffer;
    }

    pub inline fn bind(self: OpenGLVertexBuffer) void {
        gl.bindBuffer(gl.ARRAY_BUFFER, self.gl_buffer);
    }

    pub inline fn set_data(self: *OpenGLVertexBuffer, comptime T: anytype, data: []const T) types.ShaderTypeError!void {
        self.bind();
        std.heap.page_allocator.free(self.layout.elements);
        const layout = generate_layout(T, data) catch |e| {
            return e;
        };
        self.layout = layout;
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(data.len * self.layout.size), data.ptr, gl.STATIC_DRAW);
        self.unbind();
    }

    pub inline fn unbind(_: OpenGLVertexBuffer) void {
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    }
};
