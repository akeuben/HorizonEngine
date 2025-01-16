const std = @import("std");
const opengl = @import("opengl/target.zig");
const vulkan = @import("vulkan/target.zig");
const none = @import("none/target.zig");
const context = @import("context.zig");
const VertexBuffer = @import("buffer.zig").VertexBuffer;
const Pipeline = @import("shader.zig").Pipeline;
const RenderObject = @import("object.zig").RenderObject;
const log = @import("../utils/log.zig");

pub const RenderTarget = union(context.API) {
    OPEN_GL: opengl.OpenGLRenderTarget,
    VULKAN: vulkan.VulkanRenderTarget,
    NONE: none.NoneRenderTarget,

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

    pub fn start(self: *const RenderTarget) void {
        switch (self.*) {
            inline else => |case| case.start(),
        }
    }

    pub fn render(self: *const RenderTarget, object: *const RenderObject) void {
        switch (self.*) {
            inline else => |case| case.render(object),
        }
    }

    pub fn end(self: *const RenderTarget) void {
        switch (self.*) {
            inline else => |case| case.end(),
        }
    }

    pub fn submit(self: *const RenderTarget) void {
        switch (self.*) {
            inline else => |case| case.submit(),
        }
    }

    pub fn deinit(self: RenderTarget) void {
        switch (self) {
            inline else => |case| case.deinit(),
        }
    }
};
