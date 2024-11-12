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

    pub fn get_renderpass(self: VulkanRenderTarget) vk.RenderPass {
        return switch (self) {
            inline else => |case| case.get_renderpass(),
        };
    }

    pub fn start(self: *const VulkanRenderTarget, ctx: *const context.VulkanContext) void {
        switch (self.*) {
            inline else => |case| case.start(ctx),
        }
    }

    pub fn render(self: *const VulkanRenderTarget, ctx: *const context.VulkanContext, object: *const RenderObject) void {
        switch (self.*) {
            inline else => |case| case.render(ctx, object),
        }
    }

    pub fn end(self: *const VulkanRenderTarget, ctx: *const context.VulkanContext) void {
        switch (self.*) {
            inline else => |case| case.end(ctx),
        }
    }

    pub fn submit(self: *const VulkanRenderTarget, ctx: *const context.VulkanContext) void {
        switch (self.*) {
            inline else => |case| case.submit(ctx),
        }
    }

    pub fn deinit(self: VulkanRenderTarget, ctx: *const context.VulkanContext) void {
        switch (self) {
            inline else => |case| case.deinit(ctx),
        }
    }

    pub fn get_current_commandbuffer(self: VulkanRenderTarget) vk.CommandBuffer {
        return switch (self) {
            inline else => |case| case.get_current_commandbuffer(),
        };
    }
};

pub const OtherVulkanRenderTarget = struct {
    renderpass: vk.RenderPass,

    pub fn init(ctx: *const context.VulkanContext, allocator: std.mem.Allocator) !OtherVulkanRenderTarget {
        const attachment_description = vk.AttachmentDescription{
            .format = ctx.swapchain.format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = .present_src_khr,
        };

        const attachment_reference = vk.AttachmentReference{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        };

        const subpass_description = vk.SubpassDescription{
            .pipeline_bind_point = .graphics,
            .color_attachment_count = 1,
            .p_color_attachments = @ptrCast(&attachment_reference),
        };

        const renderpass_create_info = vk.RenderPassCreateInfo{
            .attachment_count = 1,
            .p_attachments = @ptrCast(&attachment_description),
            .subpass_count = 1,
            .p_subpasses = @ptrCast(&subpass_description),
        };

        const renderpass = try ctx.logical_device.device.createRenderPass(&renderpass_create_info, null);

        const t = try allocator.create(OtherVulkanRenderTarget);
        t.renderpass = renderpass;
        return t;
    }

    pub fn get_renderpass(self: OtherVulkanRenderTarget) vk.RenderPass {
        return self.renderpass;
    }

    pub fn start(_: *const OtherVulkanRenderTarget, _: *const context.VulkanContext) void {}
    pub fn render(_: *const OtherVulkanRenderTarget, _: *const context.VulkanContext, _: *const RenderObject) void {}

    pub fn end(_: *const OtherVulkanRenderTarget, _: *const context.VulkanContext) void {}
    pub fn submit(_: *const OtherVulkanRenderTarget, _: *const context.VulkanContext) void {}

    pub fn deinit(self: OtherVulkanRenderTarget, ctx: *const context.VulkanContext) void {
        ctx.logical_device.device.destroyRenderPass(self.renderpass, null);
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
