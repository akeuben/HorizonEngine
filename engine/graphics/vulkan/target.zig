const std = @import("std");
const context = @import("context.zig");
const vk = @import("vulkan");
const VulkanPipeline = @import("shader.zig").VulkanPipeline;
const VulkanVertexBuffer = @import("buffer.zig").VulkanVertexBuffer;
const log = @import("../../utils/log.zig");
const swapchain = @import("swapchain.zig");

pub const VulkanRenderTarget = union(enum) {
    DEFAULT: *SwapchainVulkanRenderTarget,
    OTHER: *OtherVulkanRenderTarget,

    pub fn init(ctx: *const context.VulkanContext, allocator: std.mem.Allocator) !*VulkanRenderTarget {
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

    pub fn init(ctx: *const context.VulkanContext, allocator: std.mem.Allocator) !*OtherVulkanRenderTarget {
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

        const target = try allocator.create(OtherVulkanRenderTarget);
        target.renderpass = renderpass;
        return target;
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
    command_buffers: [swapchain.MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer,

    pub fn init(ctx: *const context.VulkanContext, allocator: std.mem.Allocator) !*SwapchainVulkanRenderTarget {
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

        const framebuffers = try create_framebuffers(ctx, renderpass);

        const command_buffer_info = vk.CommandBufferAllocateInfo{
            .command_pool = ctx.command_pool,
            .level = .primary,
            .command_buffer_count = @intCast(swapchain.MAX_FRAMES_IN_FLIGHT),
        };

        var command_buffers: [swapchain.MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer = undefined;
        try ctx.logical_device.device.allocateCommandBuffers(&command_buffer_info, @ptrCast(&command_buffers));

        const target = try allocator.create(SwapchainVulkanRenderTarget);
        target.renderpass = renderpass;
        target.framebuffers = framebuffers;
        target.command_buffers = command_buffers;
        return target;
    }

    fn create_framebuffers(ctx: *const context.VulkanContext, renderpass: vk.RenderPass) ![]vk.Framebuffer {
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

        return framebuffers;
    }

    pub fn get_renderpass(self: SwapchainVulkanRenderTarget) vk.RenderPass {
        return self.renderpass;
    }

    pub fn start(self: *const SwapchainVulkanRenderTarget, ctx: *const context.VulkanContext) void {
        ctx.logical_device.device.resetCommandBuffer(self.command_buffers[ctx.swapchain.current_frame], .{}) catch {
            log.err("Failed to reset command buffer", .{});
        };
        const begin_info = vk.CommandBufferBeginInfo{
            .flags = .{},
            .p_inheritance_info = null,
        };

        ctx.logical_device.device.beginCommandBuffer(self.command_buffers[ctx.swapchain.current_frame], &begin_info) catch {
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

        ctx.logical_device.device.cmdBeginRenderPass(self.command_buffers[ctx.swapchain.current_frame], &pass_info, .@"inline");
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
        ctx.logical_device.device.cmdSetViewport(self.command_buffers[ctx.swapchain.current_frame], 0, 1, @ptrCast(&viewport));

        const scissor = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = ctx.swapchain.extent,
        };
        ctx.logical_device.device.cmdSetScissor(self.command_buffers[ctx.swapchain.current_frame], 0, 1, @ptrCast(&scissor));

        ctx.logical_device.device.cmdBindPipeline(self.command_buffers[ctx.swapchain.current_frame], .graphics, pipeline.pipeline);

        ctx.logical_device.device.cmdDraw(self.command_buffers[ctx.swapchain.current_frame], 3, 1, 0, 0);
    }

    pub fn end(self: *const SwapchainVulkanRenderTarget, ctx: *const context.VulkanContext) void {
        ctx.logical_device.device.cmdEndRenderPass(self.command_buffers[ctx.swapchain.current_frame]);

        ctx.logical_device.device.endCommandBuffer(self.command_buffers[ctx.swapchain.current_frame]) catch {
            log.err("Failed to record command buffer", .{});
            return;
        };
    }

    pub fn submit(self: *const SwapchainVulkanRenderTarget, ctx: *const context.VulkanContext) void {
        const wait_semaphores: []const vk.Semaphore = &.{ctx.swapchain.image_available_semaphores[ctx.swapchain.current_frame]};
        const wait_stages: vk.PipelineStageFlags = .{ .color_attachment_output_bit = true };

        const signal_semaphores: []const vk.Semaphore = &.{ctx.swapchain.render_finished_semaphores[ctx.swapchain.current_frame]};

        const submit_info = vk.SubmitInfo{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(wait_semaphores.ptr),
            .p_wait_dst_stage_mask = @ptrCast(&wait_stages),
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&self.command_buffers[ctx.swapchain.current_frame]),
            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast(signal_semaphores.ptr),
        };

        ctx.logical_device.device.queueSubmit(ctx.graphics_queue, 1, @ptrCast(&submit_info), ctx.swapchain.in_flight_fences[ctx.swapchain.current_frame]) catch {
            log.err("Failed to submit command buffer to graphics queue", .{});
        };
    }

    pub fn resize(self: *SwapchainVulkanRenderTarget, ctx: *context.VulkanContext, new_size: @Vector(2, i32)) void {
        ctx.logical_device.device.deviceWaitIdle() catch {};

        // Destroy the old framebuffers
        for (self.framebuffers) |framebuffer| {
            ctx.logical_device.device.destroyFramebuffer(framebuffer, null);
        }
        std.heap.page_allocator.free(self.framebuffers);

        // Destroy the old swapchain
        ctx.swapchain.recreate(ctx, new_size) catch {
            log.fatal("Failed to recreate swapchain", .{});
            std.process.exit(1);
        };

        // Create new framebuffers
        self.framebuffers = create_framebuffers(ctx, self.renderpass) catch {
            log.fatal("Failed to recreate framebuffers", .{});
            std.process.exit(1);
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
