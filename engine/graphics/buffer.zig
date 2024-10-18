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
                .VULKAN = vulkan.VulkanVertexBuffer.init(),
            },
            .NONE => VertexBuffer{
                .NONE = none.NoneVertexBuffer.init(),
            },
        };
    }

    pub fn bind(self: VertexBuffer) void {
        switch (self) {
            inline else => |case| case.bind(),
        }
    }

    pub fn set_data(self: VertexBuffer, comptime T: anytype, data: []const T) void {
        switch (self) {
            inline else => |case| case.set_data(T, data),
        }
    }

    pub fn unbind(self: VertexBuffer) void {
        switch (self) {
            inline else => |case| case.unbind(),
        }
    }
};
