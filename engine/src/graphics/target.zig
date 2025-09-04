const std = @import("std");
const opengl = @import("opengl/target.zig");
const vulkan = @import("vulkan/target.zig");
const context = @import("context.zig");
const VertexBuffer = @import("buffer.zig").VertexBuffer;
const Pipeline = @import("shader.zig").Pipeline;
const RenderObject = @import("object.zig").RenderObject;
const log = @import("../utils/log.zig");

/// A target for rendering. Objects can target a RenderObject to render.
/// A context has a default render target for the window.
pub const RenderTarget = union(context.API) {
    OPEN_GL: opengl.OpenGLRenderTarget,
    VULKAN: vulkan.VulkanRenderTarget,
    NONE: void,

    /// Create a new `RenderTarget`.
    ///
    /// **Parameter** `ctx`: The context to create the `RenderTarget` for.
    /// **Parameter** `allocator`: The allocator used to create the render target.
    /// **Returns** The created RenderTarget.
    pub fn init(ctx: *const context.Context, allocator: std.mem.Allocator) RenderTarget {
        return switch (ctx.*) {
            .OPEN_GL => RenderTarget{
                .OPEN_GL = opengl.OpenGLRenderTarget.init(allocator),
            },
            .VULKAN => RenderTarget{
                .VULKAN = vulkan.VulkanRenderTarget.init(allocator),
            },
            .NONE => RenderTarget{
                .NONE = {},
            },
        };
    }

    /// Starts a renderpass.
    ///
    /// **Parameter** `self`: The render target to start the pass for.
    pub fn start(self: *const RenderTarget) ActiveRenderTarget {
        switch (self.*) {
            .OPEN_GL => self.OPEN_GL.start(),
            .VULKAN => self.VULKAN.start(),
            inline else => log.not_implemented("RenderTarget::start", self.*),
        }

        return .{
            .target = self,
        };
    }

    /// Destroy the render target.
    pub fn deinit(self: RenderTarget) void {
        switch (self) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            .VULKAN => self.VULKAN.deinit(),
            inline else => log.not_implemented("RenderTarget::deinit", self),
        }
    }
};

pub const ActiveRenderTarget = struct {
    target: *const RenderTarget,

    pub fn draw(self: ActiveRenderTarget, object: *const RenderObject) ActiveRenderTarget {
        object.draw(self.target);
        return self;
    }

    pub fn end(self: ActiveRenderTarget) void {
        switch(self.target.*) {
            .OPEN_GL => self.target.OPEN_GL.end(),
            .VULKAN => self.target.VULKAN.end(),
            inline else => log.not_implemented("ActiveRenderRenderTarget::end", self.target.*),
        }
    }
};
