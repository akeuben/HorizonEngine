const std = @import("std");
const context = @import("context.zig");
const vk = @import("vulkan");
const VulkanPipeline = @import("shader.zig").VulkanPipeline;
const VulkanVertexBuffer = @import("buffer.zig").VulkanVertexBuffer;
const RenderObject = @import("../object.zig").RenderObject;
const log = @import("../../utils/log.zig");
const swapchain = @import("swapchain.zig");
const RenderTarget = @import("../target.zig").RenderTarget;

pub const VulkanRenderTarget = union(enum) {
    SWAPCHAIN: *const swapchain.Swapchain,
    OTHER: *const OtherVulkanRenderTarget,

    pub fn init(ctx: *const context.VulkanContext, allocator: std.mem.Allocator) !VulkanRenderTarget {
        return VulkanRenderTarget{
            .OTHER = try OtherVulkanRenderTarget.init(ctx, allocator),
        };
    }

    pub fn start(self: *const VulkanRenderTarget) void {
        switch (self.*) {
            inline else => |case| case.start(),
        }
    }

    pub fn end(self: *const VulkanRenderTarget) void {
        switch (self.*) {
            inline else => |case| case.end(),
        }
    }

    pub fn deinit(self: VulkanRenderTarget) void {
        switch (self) {
            inline else => |case| case.deinit(),
        }
    }

    pub fn get_current_commandbuffer(self: VulkanRenderTarget) vk.CommandBuffer {
        return switch (self) {
            inline else => |case| case.get_current_commandbuffer(),
        };
    }
};

pub const OtherVulkanRenderTarget = struct {
    ctx: *const context.VulkanContext,

    pub fn init(ctx: *const context.VulkanContext, allocator: std.mem.Allocator) !OtherVulkanRenderTarget {
        const t = try allocator.create(OtherVulkanRenderTarget);
        t.ctx = ctx;
        return t;
    }

    pub fn start(_: *const OtherVulkanRenderTarget) void {}

    pub fn end(_: *const OtherVulkanRenderTarget) void {}

    pub fn deinit(self: OtherVulkanRenderTarget) void {
        self.ctx.logical_device.device.destroyRenderPass(self.renderpass, null);
    }

    pub fn get_current_commandbuffer(_: OtherVulkanRenderTarget) vk.CommandBuffer {
        return undefined;
    }

    pub fn target(self: *const OtherVulkanRenderTarget) RenderTarget {
        return .{
            .VULKAN = .{
                .OTHER = self,
            },
        };
    }
};
