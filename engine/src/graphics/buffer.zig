//! Represents buffers in a graphics API.

const std = @import("std");
const context = @import("context.zig");
const opengl = @import("opengl/buffer.zig");
const vulkan = @import("vulkan/buffer.zig");
const log = @import("../utils/log.zig");
const types = @import("type.zig");
const zm = @import("zm");
const shader = @import("shader.zig");

/// A Vertex Buffer. Holds information about vertices on a `RenderObject`.
/// Data in a VertexBuffer is copied to the GPU.
pub const VertexBuffer = union(context.API) {
    OPEN_GL: opengl.OpenGLVertexBuffer,
    VULKAN: vulkan.VulkanVertexBuffer,
    NONE: void,

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
                .NONE = log.not_implemented("VertexBuffer::init", ctx.*),
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
            .OPEN_GL => self.OPEN_GL.set_data(T, data),
            .VULKAN => self.VULKAN.set_data(T, data),
            inline else => log.not_implemented("VertexBuffer::set_data", self),
        }
    }

    /// Gets the layout of the `VertexBuffer`
    ///
    /// **Parameter** `self`: the `VertexBuffer` to change the data for.
    /// **Returns** the layout of the `VertexBuffer`.
    pub fn get_layout(self: VertexBuffer) types.BufferLayout {
        return switch (self) {
            .OPEN_GL => self.OPEN_GL.get_layout(),
            .VULKAN => self.VULKAN.get_layout(),
            inline else => {
                log.not_implemented("VertexBuffer::get_layout", self);
                return undefined;
            },
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
            inline else => log.not_implemented("VertexBuffer::deinit", self.*),
        };
    }
};

/// An Index Buffer. Holds information about the order of indices on a `IndexRenderObject`
/// Data in an IndexBuffer is copied to the GPU.
pub const IndexBuffer = union(context.API) {
    OPEN_GL: opengl.OpenGLIndexBuffer,
    VULKAN: vulkan.VulkanIndexBuffer,
    NONE: void,

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
                .NONE = log.not_implemented("IndexBuffer::init", ctx.*),
            },
        };
    }

    /// Update the data in an `IndexBuffer`
    ///
    /// **Parameter** `self`: the `IndexBuffer` to change the data for.
    /// **Parameter** `data`: the indices the buffer should initially hold.
    pub fn set_data(self: IndexBuffer, data: []const u32) void {
        switch (self) {
            .OPEN_GL => self.OPEN_GL.set_data(data),
            .VULKAN => self.VULKAN.set_data(data),
            inline else => log.not_implemented("IndexBuffer::set_data", self),
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
            inline else => log.not_implemented("IndexBuffer::deinit", self.*),
        };
    }
};

/// An Index Buffer. Holds information about the order of indices on a `IndexRenderObject`
/// Data in an IndexBuffer is copied to the GPU.
pub const UniformBuffer = union(context.API) {
    OPEN_GL: opengl.OpenGLUniformBuffer,
    VULKAN: vulkan.VulkanUniformBuffer,
    NONE: void,

    /// Create an `IndexBuffer`
    ///
    /// **Parameter** `ctx`: the context to be used to create this buffer.
    /// **Parameter** `data`: the indices the buffer should initially hold.
    /// **Returns** the created `IndexBuffer` on success.
    pub fn init(ctx: *const context.Context, comptime T: anytype, data: T) UniformBuffer {
        return switch (ctx.*) {
            .OPEN_GL => UniformBuffer{
                .OPEN_GL = opengl.OpenGLUniformBuffer.init(ctx.OPEN_GL, T, data),
            },
            .VULKAN => UniformBuffer{
                .VULKAN = vulkan.VulkanUniformBuffer.init(ctx.VULKAN, T, data),
            },
            .NONE => UniformBuffer{
                .NONE = log.not_implemented("UniformBuffer::init", ctx.*),
            },
        };
    }

    /// Update the data in a `UniformBuffer`
    ///
    /// **Parameter** `self`: the `UniformBuffer` to change the data for.
    /// **Parameter** `T`: the type the buffer will hold. This should be a struct containing valid shader types.
    /// **Parameter** `data`: the data the buffer should initially hold.
    pub fn set_data(self: UniformBuffer, comptime T: anytype, data: T) void {
        switch (self) {
            .OPEN_GL => self.OPEN_GL.set_data(T, data),
            inline else => log.not_implemented("VertexBuffer::set_data", self),
        }
    }

    /// Gets the layout of the `UniformBuffer`
    ///
    /// **Parameter** `self`: the `UniformBuffer` to change the data for.
    /// **Returns** the layout of the `UniformBuffer`.
    pub fn get_layout(self: UniformBuffer) types.BufferLayout {
        return switch (self) {
            .OPEN_GL => self.OPEN_GL.get_layout(),
            inline else => {
                log.not_implemented("UniformBuffer::get_layout", self);
                return undefined;
            },
        };
    }

    /// Destroys the provided `UniformBuffer`
    /// Once the buffer is destroyed, it should no longer be used in any graphics operation.
    ///
    /// **Parameter** `self`: the `UniformBuffer` to destroy.
    pub fn deinit(self: *UniformBuffer) void {
        return switch (self.*) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            inline else => log.not_implemented("UniformBuffer::deinit", self.*),
        };
    }
};

