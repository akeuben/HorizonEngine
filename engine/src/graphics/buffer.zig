//! Represents buffers in a graphics API.

const context = @import("context.zig");
const opengl = @import("opengl/buffer.zig");
const vulkan = @import("vulkan/buffer.zig");
const none = @import("none/buffer.zig");
const log = @import("../utils/log.zig");
const types = @import("type.zig");

/// A Vertex Buffer. Holds information about vertices on a `RenderObject`.
/// Data in a VertexBuffer is copied to the GPU.
pub const VertexBuffer = union(context.API) {
    OPEN_GL: opengl.OpenGLVertexBuffer,
    VULKAN: vulkan.VulkanVertexBuffer,
    NONE: none.NoneVertexBuffer,

    /// Create a `VertexBuffer`
    ///
    /// **Parameter** `ctx`: the context to be used to create this buffer.
    /// **Parameter** `T`: the type the buffer will hold. This should be a struct containing valid shader types.
    /// **Parameter** `data`: the data the buffer should initially hold.
    /// **Returns** the created `VertexBuffer` on success.
    /// **Error** `ShaderTypeError`: `T` contains an invalid shader type.
    pub fn init(ctx: *const context.Context, comptime T: anytype, data: []const T) types.ShaderTypeError!VertexBuffer {
        return switch (ctx.*) {
            .OPEN_GL => VertexBuffer{
                .OPEN_GL = opengl.OpenGLVertexBuffer.init(ctx.OPEN_GL, T, data) catch |e| {
                    return e;
                },
            },
            .VULKAN => VertexBuffer{
                .VULKAN = vulkan.VulkanVertexBuffer.init(ctx.VULKAN, T, data),
            },
            .NONE => VertexBuffer{
                .NONE = none.NoneVertexBuffer.init(),
            },
        };
    }

    /// Update the data in a `VertexBuffer`
    ///
    /// **Parameter** `self`: the `VertexBuffer` to change the data for.
    /// **Parameter** `T`: the type the buffer will hold. This should be a struct containing valid shader types.
    /// **Parameter** `data`: the data the buffer should initially hold.
    pub fn set_data(self: VertexBuffer, comptime T: anytype, data: []const T) void {
        switch (self) {
            inline else => |case| case.set_data(T, data),
        }
    }

    /// Gets the layout of the `VertexBuffer`
    ///
    /// **Parameter** `self`: the `VertexBuffer` to change the data for.
    /// **Returns** the layout of the `VertexBuffer`.
    pub fn get_layout(self: VertexBuffer) types.BufferLayout {
        return switch (self) {
            inline else => |case| case.get_layout(),
        };
    }

    /// Destroys the provided `VertexBuffer`
    /// Once the buffer is destroyed, it should no longer be used in any graphics operation.
    ///
    /// **Parameter** `self`: the `VertexBuffer` to destroy.
    pub fn deinit(self: *VertexBuffer) void {
        return switch (self.*) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            .VULKAN => self.VULKAN.deinit(),
            .NONE => self.NONE.deinit(),
        };
    }
};

/// An Index Buffer. Holds information about the order of indices on a `IndexRenderObject`
/// Data in an IndexBuffer is copied to the GPU.
pub const IndexBuffer = union(context.API) {
    OPEN_GL: opengl.OpenGLIndexBuffer,
    VULKAN: vulkan.VulkanIndexBuffer,
    NONE: none.NoneIndexBuffer,

    /// Create an `IndexBuffer`
    ///
    /// **Parameter** `ctx`: the context to be used to create this buffer.
    /// **Parameter** `data`: the indices the buffer should initially hold.
    /// **Returns** the created `IndexBuffer` on success.
    pub fn init(ctx: *const context.Context, data: []const u32) IndexBuffer {
        return switch (ctx.*) {
            .OPEN_GL => IndexBuffer{
                .OPEN_GL = opengl.OpenGLIndexBuffer.init(ctx.OPEN_GL, data),
            },
            .VULKAN => IndexBuffer{
                .VULKAN = vulkan.VulkanIndexBuffer.init(ctx.VULKAN, data),
            },
            .NONE => IndexBuffer{
                .NONE = none.NoneIndexBuffer.init(),
            },
        };
    }

    /// Update the data in an `IndexBuffer`
    ///
    /// **Parameter** `self`: the `IndexBuffer` to change the data for.
    /// **Parameter** `data`: the indices the buffer should initially hold.
    pub fn set_data(self: IndexBuffer, data: []const u32) void {
        switch (self) {
            inline else => |case| case.set_data(data),
        }
    }

    /// Destroys the provided `IndexBuffer`
    /// Once the buffer is destroyed, it should no longer be used in any graphics operation.
    ///
    /// **Parameter** `self`: the `IndexBuffer` to destroy.
    pub fn deinit(self: *IndexBuffer) void {
        return switch (self.*) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            .VULKAN => self.VULKAN.deinit(),
            .NONE => self.NONE.deinit(),
        };
    }
};
