///! This module provides structures representing an object to be rendered.
///! This is an abstraction around the different methods to render an object,
///! such as basic lists of vertices, indexed rendering, triangle strips, instanced rendering, etc...
const context = @import("context.zig");
const opengl = @import("opengl/object.zig");
const vulkan = @import("vulkan/object.zig");
const none = @import("none/object.zig");
const shader = @import("shader.zig");
const buffer = @import("buffer.zig");
const RenderTarget = @import("target.zig").RenderTarget;

/// A object that can be rendered to a `RenderTarget`
pub const RenderObject = struct {
    ptr: *const anyopaque,
    drawFn: *const fn (ptr: *const anyopaque, target: *const RenderTarget) void,

    fn init(ptr: anytype) RenderObject {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn draw(pointer: *const anyopaque, target: *const RenderTarget) void {
                const self: T = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.pointer.child.draw, .{ self, target });
            }
        };

        return .{
            .ptr = ptr,
            .drawFn = gen.draw,
        };
    }

    /// Draw the object to the specified render target
    ///
    /// **Parameter** `self`: The render object to render.
    /// **Parameter** `target`: The target to render to.
    pub fn draw(self: *const RenderObject, target: *const RenderTarget) void {
        return self.drawFn(self.ptr, target);
    }
};

/// A render object for a list of vertices forming a triangle for each instance of 3 elements
pub const VertexRenderObject = union(context.API) {
    OPEN_GL: opengl.OpenGLVertexRenderObject,
    VULKAN: vulkan.VulkanVertexRenderObject,
    NONE: none.NoneVertexRenderObject,

    /// Create a `VertexRenderObject`
    ///
    /// **Parameter** `ctx`: The rendering context to bind this `RenderObject` to.
    /// **Parameter** `pipeline`: The pipeline this render object uses.
    /// **Parameter** `vertices`: The list of vertices that will be drawn to the target.
    pub fn init(ctx: *const context.Context, pipeline: *const shader.Pipeline, vertices: *const buffer.VertexBuffer) VertexRenderObject {
        return switch (ctx.*) {
            .OPEN_GL => .{
                .OPEN_GL = opengl.OpenGLVertexRenderObject.init(ctx.OPEN_GL, &pipeline.OPEN_GL, &vertices.OPEN_GL),
            },
            .VULKAN => .{
                .VULKAN = vulkan.VulkanVertexRenderObject.init(ctx.VULKAN, &pipeline.VULKAN, &vertices.VULKAN),
            },
            .NONE => .{
                .NONE = none.NoneVertexRenderObject.init(ctx.NONE, &pipeline.NONE, &vertices.NONE),
            },
        };
    }

    /// Draw the object to the specified render target
    ///
    /// **Parameter** `self`: The render object to render.
    /// **Parameter** `target`: The target to render to.
    pub fn draw(self: *const VertexRenderObject, target: *const RenderTarget) void {
        switch (self.*) {
            .OPEN_GL => self.OPEN_GL.draw(&target.OPEN_GL),
            .VULKAN => self.VULKAN.draw(&target.VULKAN),
            .NONE => self.NONE.draw(&target.NONE),
        }
    }

    // Convert to a `RenderObject`
    //
    /// **Parameter** `self`: The render object to abstract.
    pub fn object(self: *const VertexRenderObject) RenderObject {
        return RenderObject.init(self);
    }
};

pub const IndexRenderObject = union(context.API) {
    OPEN_GL: opengl.OpenGLIndexRenderObject,
    VULKAN: vulkan.VulkanIndexRenderObject,
    NONE: none.NoneIndexRenderObject,

    /// Create a `IndexRenderObject`
    ///
    /// **Parameter** `ctx`: The rendering context to bind this `RenderObject` to.
    /// **Parameter** `pipeline`: The pipeline this render object uses.
    /// **Parameter** `vertices`: The list of vertices that will be drawn to the target.
    pub fn init(ctx: *const context.Context, pipeline: *const shader.Pipeline, vertices: *const buffer.VertexBuffer, indices: *const buffer.IndexBuffer) IndexRenderObject {
        return switch (ctx.*) {
            .OPEN_GL => .{
                .OPEN_GL = opengl.OpenGLIndexRenderObject.init(ctx.OPEN_GL, &pipeline.OPEN_GL, &vertices.OPEN_GL, &indices.OPEN_GL),
            },
            .VULKAN => .{
                .VULKAN = vulkan.VulkanIndexRenderObject.init(ctx.VULKAN, &pipeline.VULKAN, &vertices.VULKAN, &indices.VULKAN),
            },
            .NONE => .{
                .NONE = none.NoneIndexRenderObject.init(ctx.NONE, &pipeline.NONE, &vertices.NONE, &indices.NONE),
            },
        };
    }

    /// Draw the object to the specified render target
    ///
    /// **Parameter** `self`: The render object to render.
    /// **Parameter** `target`: The target to render to.
    pub fn draw(self: *const IndexRenderObject, target: *const RenderTarget) void {
        switch (self.*) {
            .OPEN_GL => self.OPEN_GL.draw(&target.OPEN_GL),
            .VULKAN => self.VULKAN.draw(&target.VULKAN),
            .NONE => self.NONE.draw(&target.NONE),
        }
    }

    // Convert to a `RenderObject`
    //
    /// **Parameter** `self`: The render object to abstract.
    pub fn object(self: *const IndexRenderObject) RenderObject {
        return RenderObject.init(self);
    }
};
