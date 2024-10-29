const std = @import("std");
const context = @import("context.zig");
const vk = @import("vulkan");
const VulkanPipeline = @import("shader.zig").VulkanPipeline;
const VulkanVertexBuffer = @import("buffer.zig").VulkanVertexBuffer;
const log = @import("../../utils/log.zig");

pub const VulkanRenderTarget = union(enum) {
    DEFAULT: SwapchainVulkanRenderTarget,
    OTHER: OtherVulkanRenderTarget,

    pub fn init(ctx: *const context.VulkanContext) !VulkanRenderTarget {
        return VulkanRenderTarget{
            .OTHER = try OtherVulkanRenderTarget.init(ctx),
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

    pub fn render(self: *const VulkanRenderTarget, ctx: *const context.VulkanContext, pipeline: *const VulkanPipeline, buffer: *const VulkanVertexBuffer) void {
        switch (self.*) {
            inline else => |case| case.render(ctx, pipeline, buffer),
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
};

pub const OtherVulkanRenderTarget = struct {
    renderpass: vk.RenderPass,

    pub fn init(ctx: *const context.VulkanContext) !OtherVulkanRenderTarget {
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

        return OtherVulkanRenderTarget{
            .renderpass = renderpass,
        };
    }

    pub fn get_renderpass(self: OtherVulkanRenderTarget) vk.RenderPass {
        return self.renderpass;
    }

    pub fn start(_: *const OtherVulkanRenderTarget, _: *const context.VulkanContext) void {}

    pub fn render(_: *const OtherVulkanRenderTarget, _: *const context.VulkanContext, _: *const VulkanPipeline, _: *const VulkanVertexBuffer) void {}

    pub fn end(_: *const OtherVulkanRenderTarget, _: *const context.VulkanContext) void {}
    pub fn submit(_: *const OtherVulkanRenderTarget, _: *const context.VulkanContext) void {}

    pub fn deinit(self: OtherVulkanRenderTarget, ctx: *const context.VulkanContext) void {
        ctx.logical_device.device.destroyRenderPass(self.renderpass, null);
    }
};

pub const SwapchainVulkanRenderTarget = struct {
    renderpass: vk.RenderPass,
    framebuffers: []vk.Framebuffer,
    command_buffer: vk.CommandBuffer,

    pub fn init(ctx: *const context.VulkanContext) !SwapchainVulkanRenderTarget {
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

        const subpass_dependency = vk.SubpassDependency{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .color_attachment_output_bit = true },
            .src_access_mask = .{},
            .dst_stage_mask = .{ .color_attachment_output_bit = true },
            .dst_access_mask = .{ .color_attachment_write_bit = true },
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
            .dependency_count = 1,
            .p_dependencies = @ptrCast(&subpass_dependency),
        };

        const renderpass = try ctx.logical_device.device.createRenderPass(&renderpass_create_info, null);

        const framebuffers = try std.heap.page_allocator.alloc(vk.Framebuffer, ctx.swapchain.image_views.len);

        for (ctx.swapchain.image_views, 0..) |image_view, i| {
            const attachments: []const vk.ImageView = &.{image_view};
            const info = vk.FramebufferCreateInfo{
                .render_pass = renderpass,
                .attachment_count = 1,
                .p_attachments = @ptrCast(attachments.ptr),
                .width = ctx.swapchain.extent.width,
                .height = ctx.swapchain.extent.height,
                .layers = 1,
            };
            framebuffers[i] = try ctx.logical_device.device.createFramebuffer(@ptrCast(&info), null);
        }

        const command_buffer_info = vk.CommandBufferAllocateInfo{
            .command_pool = ctx.command_pool,
            .level = .primary,
            .command_buffer_count = 1,
        };

        var command_buffer: vk.CommandBuffer = undefined;
        try ctx.logical_device.device.allocateCommandBuffers(&command_buffer_info, @ptrCast(&command_buffer));

        return SwapchainVulkanRenderTarget{
            .renderpass = renderpass,
            .framebuffers = framebuffers,
            .command_buffer = command_buffer,
        };
    }

    pub fn get_renderpass(self: SwapchainVulkanRenderTarget) vk.RenderPass {
        return self.renderpass;
    }

    pub fn start(self: *const SwapchainVulkanRenderTarget, ctx: *const context.VulkanContext) void {
        ctx.logical_device.device.resetCommandBuffer(self.command_buffer, .{}) catch {
            log.err("Failed to reset command buffer", .{});
        };
        const begin_info = vk.CommandBufferBeginInfo{
            .flags = .{},
            .p_inheritance_info = null,
        };

        ctx.logical_device.device.beginCommandBuffer(self.command_buffer, &begin_info) catch {
            log.err("Failed to start command buffer", .{});
            return;
        };

        const clear_color = vk.ClearValue{ .color = .{ .float_32 = .{ 0, 0, 0, 1 } } };

        const pass_info = vk.RenderPassBeginInfo{
            .render_pass = self.renderpass,
            .framebuffer = self.framebuffers[ctx.swapchain.current_image_index.?],
            .render_area = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = ctx.swapchain.extent,
            },
            .clear_value_count = 1,
            .p_clear_values = @ptrCast(&clear_color),
        };

        ctx.logical_device.device.cmdBeginRenderPass(self.command_buffer, &pass_info, .@"inline");
    }

    pub fn render(self: *const SwapchainVulkanRenderTarget, ctx: *const context.VulkanContext, pipeline: *const VulkanPipeline, _: *const VulkanVertexBuffer) void {
        const viewport = vk.Viewport{
            .x = 0,
            .y = @as(f32, @floatFromInt(ctx.swapchain.extent.height)),
            .width = @floatFromInt(ctx.swapchain.extent.width),
            .height = -@as(f32, @floatFromInt(ctx.swapchain.extent.height)),
            .min_depth = 0,
            .max_depth = 1,
        };
        ctx.logical_device.device.cmdSetViewport(self.command_buffer, 0, 1, @ptrCast(&viewport));

        const scissor = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = ctx.swapchain.extent,
        };
        ctx.logical_device.device.cmdSetScissor(self.command_buffer, 0, 1, @ptrCast(&scissor));

        ctx.logical_device.device.cmdBindPipeline(self.command_buffer, .graphics, pipeline.pipeline);

        ctx.logical_device.device.cmdDraw(self.command_buffer, 3, 1, 0, 0);
    }

    pub fn end(self: *const SwapchainVulkanRenderTarget, ctx: *const context.VulkanContext) void {
        ctx.logical_device.device.cmdEndRenderPass(self.command_buffer);

        ctx.logical_device.device.endCommandBuffer(self.command_buffer) catch {
            log.err("Failed to record command buffer", .{});
            return;
        };
    }

    pub fn submit(self: *const SwapchainVulkanRenderTarget, ctx: *const context.VulkanContext) void {
        const wait_semaphores: []const vk.Semaphore = &.{ctx.swapchain.image_available_semaphore};
        const wait_stages: vk.PipelineStageFlags = .{ .color_attachment_output_bit = true };

        const signal_semaphores: []const vk.Semaphore = &.{ctx.swapchain.render_finished_semaphore};

        const submit_info = vk.SubmitInfo{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(wait_semaphores.ptr),
            .p_wait_dst_stage_mask = @ptrCast(&wait_stages),
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&self.command_buffer),
            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast(signal_semaphores.ptr),
        };

        ctx.logical_device.device.queueSubmit(ctx.graphics_queue, 1, @ptrCast(&submit_info), ctx.swapchain.in_flight_fence) catch {
            log.err("Failed to submit command buffer to graphics queue", .{});
        };
    }

    pub fn deinit(self: SwapchainVulkanRenderTarget, ctx: *const context.VulkanContext) void {
        for (self.framebuffers) |framebuffer| {
            ctx.logical_device.device.destroyFramebuffer(framebuffer, null);
        }
        std.heap.page_allocator.free(self.framebuffers);
        ctx.logical_device.device.destroyRenderPass(self.renderpass, null);
    }
};
