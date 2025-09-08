const std = @import("std");
const gl = @import("gl");
const types = @import("../type.zig");
const log = @import("../../utils/log.zig");
const context = @import("./context.zig");
const shader = @import("../shader.zig");
const zm = @import("zm"); 

pub const OpenGLVertexBuffer = struct {
    gl_buffer: u32,
    ctx: *const context.OpenGLContext,
    layout: ?types.BufferLayout,

    pub fn init(ctx: *const context.OpenGLContext, comptime T: anytype, data: []const T) types.ShaderTypeError!OpenGLVertexBuffer {
        var gl_buffer: u32 = 0;
        gl.genBuffers(1, &gl_buffer);
        log.debug("Generated buffer {}", .{gl_buffer});

        // Get information on attribute types in T
        var buffer: OpenGLVertexBuffer = undefined;
        buffer.gl_buffer = gl_buffer;
        buffer.ctx = ctx;
        buffer.layout = null;

        try buffer.set_data(T, data);
        return buffer;
    }

    pub inline fn set_data(self: *OpenGLVertexBuffer, comptime T: anytype, data: []const T) types.ShaderTypeError!void {
        gl.bindBuffer(gl.ARRAY_BUFFER, self.gl_buffer);
        if (self.layout != null) {
            self.layout.?.deinit();
        }
        const layout = types.generate_layout(T, data, self.ctx.allocator) catch |e| {
            return e;
        };
        self.layout = layout;
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(data.len * self.layout.?.size), data.ptr, gl.STATIC_DRAW);
    }

    pub fn get_layout(self: OpenGLVertexBuffer) types.BufferLayout {
        return self.layout.?;
    }

    pub fn deinit(self: *OpenGLVertexBuffer) void {
        self.layout.?.deinit();
        gl.deleteBuffers(1, &self.gl_buffer);
    }
};

pub const OpenGLIndexBuffer = struct {
    gl_buffer: u32,
    count: u32,

    pub fn init(_: *const context.OpenGLContext, data: []const u32) OpenGLIndexBuffer {
        var gl_buffer: u32 = 0;
        gl.genBuffers(1, &gl_buffer);
        log.debug("Generated buffer {} count: {}", .{ gl_buffer, data.len });

        var buffer = OpenGLIndexBuffer{
            .gl_buffer = gl_buffer,
            .count = @intCast(data.len),
        };
        buffer.set_data(data);
        return buffer;
    }

    pub inline fn set_data(self: *OpenGLIndexBuffer, data: []const u32) void {
        self.count = @intCast(data.len);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.gl_buffer);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(data.len * @sizeOf(u32)), data.ptr, gl.STATIC_DRAW);
    }

    pub fn deinit(self: *OpenGLIndexBuffer) void {
        gl.deleteBuffers(1, &self.gl_buffer);
    }
};

pub const OpenGLUniformBuffer = struct {
    ctx: *const context.OpenGLContext,
    gl_buffer: u32,
    layout: ?types.BufferLayout,

    pub fn init(ctx: *const context.OpenGLContext, comptime T: anytype, data: T) OpenGLUniformBuffer {
        var gl_buffer: u32 = 0;
        gl.genBuffers(1, &gl_buffer);
        log.debug("Generated buffer {}", .{ gl_buffer });

        var buffer = OpenGLUniformBuffer{
            .ctx = ctx,
            .gl_buffer = gl_buffer,
            .layout = null,
        };
        buffer.set_data(T, data);
        return buffer;
    }

    pub inline fn set_data(self: *OpenGLUniformBuffer, comptime T: anytype, data: T) void {
        const layout = types.generate_layout(T, &.{data}, self.ctx.allocator) catch {
            log.fatal("Uniform Buffer contains an invalid type", .{});
        };

        self.layout = layout;
        gl.bindBuffer(gl.UNIFORM_BUFFER, self.gl_buffer);
        gl.bufferData(gl.UNIFORM_BUFFER, layout.size, &data, gl.STATIC_DRAW);
    }

    pub fn get_layout(self: OpenGLUniformBuffer) types.BufferLayout {
        return self.layout.?;
    }

    pub fn deinit(self: *OpenGLUniformBuffer) void {
        gl.deleteBuffers(1, &self.gl_buffer);
    }
};
