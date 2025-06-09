const std = @import("std");
const opengl = @import("opengl/target.zig");
const vulkan = @import("vulkan/target.zig");
const none = @import("none/target.zig");
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
    NONE: none.NoneRenderTarget,

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
                .NONE = none.NoneRenderTarget.init(allocator),
            },
        };
    }

    /// Starts a renderpass.
    ///
    /// **Parameter** `self`: The render target to start the pass for.
    pub fn start(self: *const RenderTarget) ActiveRenderTarget {
        switch (self.*) {
            inline else => |case| case.start(),
        }

        return .{
            .target = self,
        };
    }

    /// Destroy the render target.
    pub fn deinit(self: RenderTarget) void {
        switch (self) {
            inline else => |case| case.deinit(),
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
            inline else => |case| case.end(),
        }
    }
};
