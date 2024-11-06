const context = @import("context.zig");
const opengl = @import("opengl/buffer.zig");
const vulkan = @import("vulkan/buffer.zig");
const none = @import("none/buffer.zig");
const log = @import("../utils/log.zig");
const types = @import("type.zig");

pub const VertexBuffer = union(context.API) {
    OPEN_GL: opengl.OpenGLVertexBuffer,
    VULKAN: vulkan.VulkanVertexBuffer,
    NONE: none.NoneVertexBuffer,

    pub fn init(ctx: *const context.Context, comptime T: anytype, data: []const T) types.ShaderTypeError!VertexBuffer {
        return switch (ctx.*) {
            .OPEN_GL => VertexBuffer{
                .OPEN_GL = opengl.OpenGLVertexBuffer.init(T, data) catch |e| {
                    return e;
                },
            },
            .VULKAN => VertexBuffer{
                .VULKAN = vulkan.VulkanVertexBuffer.init(&ctx.VULKAN, T, data),
            },
            .NONE => VertexBuffer{
                .NONE = none.NoneVertexBuffer.init(),
            },
        };
    }

    pub fn set_data(self: VertexBuffer, comptime T: anytype, data: []const T) void {
        switch (self) {
            inline else => |case| case.set_data(T, data),
        }
    }

    pub fn get_layout(self: VertexBuffer) types.BufferLayout {
        return switch (self) {
            inline else => |case| case.get_layout(),
        };
    }

    pub fn deinit(self: VertexBuffer, ctx: *const context.Context) void {
        return switch (self) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            .VULKAN => self.VULKAN.deinit(&ctx.VULKAN),
            .NONE => self.NONE.deinit(),
        };
    }
};

pub const IndexBuffer = union(context.API) {
    OPEN_GL: opengl.OpenGLIndexBuffer,
    VULKAN: vulkan.VulkanIndexBuffer,
    NONE: none.NoneIndexBuffer,

    pub fn init(ctx: *const context.Context, data: []const u32) types.ShaderTypeError!IndexBuffer {
        return switch (ctx.*) {
            .OPEN_GL => IndexBuffer{
                .OPEN_GL = opengl.OpenGLIndexBuffer.init(data) catch |e| {
                    return e;
                },
            },
            .VULKAN => IndexBuffer{
                .VULKAN = vulkan.VulkanIndexBuffer.init(&ctx.VULKAN, data),
            },
            .NONE => IndexBuffer{
                .NONE = none.NoneIndexBuffer.init(),
            },
        };
    }

    pub fn set_data(self: IndexBuffer, data: []const u32) void {
        switch (self) {
            inline else => |case| case.set_data(data),
        }
    }

    pub fn deinit(self: IndexBuffer, ctx: *const context.Context) void {
        return switch (self) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            .VULKAN => self.VULKAN.deinit(&ctx.VULKAN),
            .NONE => self.NONE.deinit(),
        };
    }
};
