const std = @import("std");
const opengl = @import("opengl/target.zig");
const vulkan = @import("vulkan/target.zig");
const none = @import("none/target.zig");
const context = @import("context.zig");
const VertexBuffer = @import("buffer.zig").VertexBuffer;
const Pipeline = @import("shader.zig").Pipeline;
const log = @import("../utils/log.zig");

pub const RenderTarget = union(context.API) {
    OPEN_GL: *opengl.OpenGLRenderTarget,
    VULKAN: *vulkan.VulkanRenderTarget,
    NONE: *none.NoneRenderTarget,

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

    pub fn start(self: *const RenderTarget, ctx: *const context.Context) void {
        switch (self.*) {
            .OPEN_GL => opengl.OpenGLRenderTarget.start(self.OPEN_GL, &ctx.OPEN_GL),
            .VULKAN => vulkan.VulkanRenderTarget.start(self.VULKAN, &ctx.VULKAN),
            .NONE => none.NoneRenderTarget.start(self.NONE, &ctx.NONE),
        }
    }

    pub fn render(self: *const RenderTarget, ctx: *const context.Context, pipeline: *const Pipeline, buffer: *const VertexBuffer) void {
        switch (self.*) {
            .OPEN_GL => opengl.OpenGLRenderTarget.render(self.OPEN_GL, &ctx.OPEN_GL, &pipeline.OPEN_GL, &buffer.OPEN_GL),
            .VULKAN => vulkan.VulkanRenderTarget.render(self.VULKAN, &ctx.VULKAN, &pipeline.VULKAN, &buffer.VULKAN),
            .NONE => none.NoneRenderTarget.render(self.NONE, &ctx.NONE, &pipeline.NONE, &buffer.NONE),
        }
    }

    pub fn end(self: *const RenderTarget, ctx: *const context.Context) void {
        switch (self.*) {
            .OPEN_GL => opengl.OpenGLRenderTarget.end(self.OPEN_GL, &ctx.OPEN_GL),
            .VULKAN => vulkan.VulkanRenderTarget.end(self.VULKAN, &ctx.VULKAN),
            .NONE => none.NoneRenderTarget.end(self.NONE, &ctx.NONE),
        }
    }

    pub fn submit(self: *const RenderTarget, ctx: *const context.Context) void {
        switch (self.*) {
            .OPEN_GL => opengl.OpenGLRenderTarget.submit(self.OPEN_GL, &ctx.OPEN_GL),
            .VULKAN => vulkan.VulkanRenderTarget.submit(self.VULKAN, &ctx.VULKAN),
            .NONE => none.NoneRenderTarget.submit(self.NONE, &ctx.NONE),
        }
    }

    pub fn deinit(self: RenderTarget) void {
        switch (self) {
            inline else => |case| case.deinit(),
        }
    }
};
