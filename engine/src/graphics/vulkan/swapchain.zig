const std = @import("std");
const vk = @import("vulkan");
const context = @import("context.zig");
const Window = @import("../../platform/window.zig").Window;
const queue = @import("queue.zig");
const device = @import("device.zig");
const log = @import("../../utils/log.zig");
const RenderObject = @import("../object.zig").RenderObject;
const RenderTarget = @import("../target.zig").RenderTarget;

pub const MAX_FRAMES_IN_FLIGHT: comptime_int = 2;

pub const SwapChainSupportDetails = struct {
    capabilities: vk.SurfaceCapabilitiesKHR,
    formats: []const vk.SurfaceFormatKHR,
    present_modes: []const vk.PresentModeKHR,
    allocator: std.mem.Allocator,

    pub fn deinit(self: SwapChainSupportDetails) void {
        self.allocator.free(self.formats);
        self.allocator.free(self.present_modes);
    }
};

pub fn query_swapchain_support(ctx: *const context.VulkanContext, physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR, allocator: std.mem.Allocator) !SwapChainSupportDetails {
    var swapchain_support_details: SwapChainSupportDetails = undefined;

    swapchain_support_details.allocator = allocator;
    swapchain_support_details.capabilities = try ctx.instance.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface);
    swapchain_support_details.formats = try ctx.instance.instance.getPhysicalDeviceSurfaceFormatsAllocKHR(physical_device, surface, allocator);
    swapchain_support_details.present_modes = try ctx.instance.instance.getPhysicalDeviceSurfacePresentModesAllocKHR(physical_device, surface, allocator);

    return swapchain_support_details;
}

fn choose_swapchain_format(available_formats: []const vk.SurfaceFormatKHR) vk.SurfaceFormatKHR {
    for (available_formats) |format| {
        if (format.format == .b8g8r8a8_srgb and format.color_space == .srgb_nonlinear_khr) {
            return format;
        }
    }

    return available_formats[0];
}

fn choose_swapchain_present_mode(available_present_modes: []const vk.PresentModeKHR) vk.PresentModeKHR {
    for (available_present_modes) |present_mode| {
        if (present_mode == .mailbox_khr) {
            return present_mode;
        }
    }

    return vk.PresentModeKHR.fifo_khr;
}

fn choose_swap_extent(size: @Vector(2, i32), capabilities: *const vk.SurfaceCapabilitiesKHR) vk.Extent2D {
    if (capabilities.current_extent.width != std.math.maxInt(u32)) {
        return capabilities.current_extent;
    }

    const extent: vk.Extent2D = .{
        .width = std.math.clamp(
            @as(u32, @intCast(size[0])),
            capabilities.min_image_extent.width,
            capabilities.max_image_extent.width,
        ),
        .height = std.math.clamp(
            @as(u32, @intCast(size[1])),
            capabilities.min_image_extent.height,
            capabilities.max_image_extent.height,
        ),
    };

    return extent;
}

pub const AcquireImageError = error{ OutOfDateSwapchain, Other };

pub const Swapchain = struct {
    ctx: *const context.VulkanContext,
    swapchain: vk.SwapchainKHR,
    images: []vk.Image,
    image_views: []vk.ImageView,
    format: vk.Format,
    extent: vk.Extent2D,
    current_image_index: ?usize,
    current_frame: usize,
    in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence,
    image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
    render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
    command_buffers: [MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer,
    resized: bool,
    allocator: std.mem.Allocator,
    renderpass: vk.RenderPass,
    framebuffers: []vk.Framebuffer,

    pub fn init(ctx: *const context.VulkanContext, window: *const Window, allocator: std.mem.Allocator) !Swapchain {
        var swapchain: Swapchain = undefined;
        swapchain.ctx = ctx;
        swapchain.current_image_index = null;
        swapchain.current_frame = 0;
        swapchain.allocator = allocator;
        swapchain.resized = false;
        swapchain.swapchain = .null_handle;

        try create_swapchain(&swapchain, window.get_size_pixels());
        try create_image_views(&swapchain);

        var image_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore = @splat(undefined);
        var render_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore = @splat(undefined);
        var fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence = @splat(undefined);

        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            fences[i] = try ctx.logical_device.device.createFence(&vk.FenceCreateInfo{
                .flags = .{ .signaled_bit = true },
            }, null);
            image_semaphores[i] = try ctx.logical_device.device.createSemaphore(&.{}, null);
            render_semaphores[i] = try ctx.logical_device.device.createSemaphore(&.{}, null);
        }

        swapchain.in_flight_fences = fences;
        swapchain.image_available_semaphores = image_semaphores;
        swapchain.render_finished_semaphores = render_semaphores;

        const attachment_description = vk.AttachmentDescription{
            .format = swapchain.format,
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

        swapchain.renderpass = try ctx.logical_device.device.createRenderPass(&renderpass_create_info, null);

        swapchain.framebuffers = try create_framebuffers(&swapchain);

        const command_buffer_info = vk.CommandBufferAllocateInfo{
            .command_pool = ctx.command_pool,
            .level = .primary,
            .command_buffer_count = @intCast(MAX_FRAMES_IN_FLIGHT),
        };

        try ctx.logical_device.device.allocateCommandBuffers(&command_buffer_info, @ptrCast(&swapchain.command_buffers));

        return swapchain;
    }

    fn create_framebuffers(self: *const Swapchain) ![]vk.Framebuffer {
        const framebuffers = try std.heap.page_allocator.alloc(vk.Framebuffer, self.image_views.len);

        for (self.image_views, 0..) |image_view, i| {
            const attachments: []const vk.ImageView = &.{image_view};
            const info = vk.FramebufferCreateInfo{
                .render_pass = self.renderpass,
                .attachment_count = 1,
                .p_attachments = @ptrCast(attachments.ptr),
                .width = self.extent.width,
                .height = self.extent.height,
                .layers = 1,
            };
            framebuffers[i] = try self.ctx.logical_device.device.createFramebuffer(@ptrCast(&info), null);
        }

        return framebuffers;
    }

    fn create_swapchain(self: *Swapchain, size: @Vector(2, i32)) !void {
        const support = try query_swapchain_support(self.ctx, self.ctx.physical_device.device, self.ctx.surface, std.heap.page_allocator);
        defer support.deinit();

        const format = choose_swapchain_format(support.formats);
        const present_mode = choose_swapchain_present_mode(support.present_modes);
        const extent = choose_swap_extent(size, &support.capabilities);

        var image_count: u32 = support.capabilities.min_image_count + 1;
        if (support.capabilities.max_image_count > 0 and image_count > support.capabilities.max_image_count) {
            image_count = support.capabilities.max_image_count;
        }

        const indices = try queue.find_queue_families(self.ctx, self.ctx.physical_device.device);
        const queue_family_indices: ?[]const u32 = if (indices.graphics_family.? == indices.present_family.?)
            null
        else
            &.{ indices.graphics_family.?, indices.present_family.? };

        const image_sharing_mode: vk.SharingMode = if (indices.graphics_family.? == indices.present_family.?)
            vk.SharingMode.exclusive
        else
            vk.SharingMode.concurrent;
        const queue_family_index_count: u32 = if (indices.graphics_family.? == indices.present_family.?)
            0
        else
            2;

        const create_info: vk.SwapchainCreateInfoKHR = .{
            .surface = self.ctx.surface,
            .min_image_count = image_count,
            .image_format = format.format,
            .image_color_space = format.color_space,
            .image_extent = extent,
            .image_array_layers = 1,
            .image_usage = .{
                .color_attachment_bit = true,
            },
            .image_sharing_mode = image_sharing_mode,
            .queue_family_index_count = queue_family_index_count,
            .p_queue_family_indices = @ptrCast(queue_family_indices),
            .pre_transform = support.capabilities.current_transform,
            .composite_alpha = .{
                .opaque_bit_khr = true,
            },
            .present_mode = present_mode,
            .clipped = vk.TRUE,
            .old_swapchain = self.swapchain,
        };

        self.swapchain = try self.ctx.logical_device.device.createSwapchainKHR(&create_info, null);
        self.format = format.format;
        self.extent = extent;
    }

    fn create_image_views(self: *Swapchain) !void {
        const images = try self.ctx.logical_device.device.getSwapchainImagesAllocKHR(self.swapchain, self.allocator);

        const image_views = try self.allocator.alloc(vk.ImageView, images.len);
        for (images, 0..) |image, i| {
            const view_create_info: vk.ImageViewCreateInfo = .{
                .image = image,
                .view_type = .@"2d",
                .format = self.format,
                .components = .{
                    .r = .identity,
                    .g = .identity,
                    .b = .identity,
                    .a = .identity,
                },
                .subresource_range = .{
                    .aspect_mask = .{ .color_bit = true },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
            };
            image_views[i] = try self.ctx.logical_device.device.createImageView(&view_create_info, null);
        }

        self.images = images;
        self.image_views = image_views;
    }

    pub fn recreate(self: *Swapchain, size: @Vector(2, i32)) !void {
        self.ctx.logical_device.device.deviceWaitIdle() catch {};

        for (self.image_views) |view| {
            self.ctx.logical_device.device.destroyImageView(view, null);
        }
        const old_swapchain = self.swapchain;

        try create_swapchain(self, size);
        self.ctx.logical_device.device.destroySwapchainKHR(old_swapchain, null);
        try create_image_views(self);
    }

    pub fn acquire_image(self: *Swapchain) AcquireImageError!void {
        const r = self.ctx.logical_device.device.waitForFences(1, @ptrCast(&self.in_flight_fences[self.current_frame]), vk.TRUE, std.math.maxInt(u64)) catch {
            log.err("Failed to wait for previous frame to finish!", .{});
            return undefined;
        };

        if (r != .success) {
            log.err("Failed to wait for previous frame to finish!", .{});
        }

        const result = self.ctx.logical_device.device.acquireNextImageKHR(self.swapchain, std.math.maxInt(u64), self.image_available_semaphores[self.current_frame], .null_handle) catch {
            log.err("Failed to acquire next image from swapchain!", .{});
            return AcquireImageError.Other;
        };

        if (result.result == .error_out_of_date_khr) {
            log.info("Failed to acquire next image from swapchain!", .{});
            return AcquireImageError.OutOfDateSwapchain;
        } else if (result.result != .success and result.result != .suboptimal_khr) {
            log.err("Failed to acquire next image from swapchain!", .{});
            return AcquireImageError.Other;
        }

        self.ctx.logical_device.device.resetFences(1, @ptrCast(&self.in_flight_fences[self.current_frame])) catch {
            log.err("Failed to reset previous frame fence", .{});
        };

        self.current_image_index = result.image_index;
    }

    pub fn swap(self: *Swapchain, window: *const Window) void {
        const wait_semaphores: []const vk.Semaphore = &.{self.render_finished_semaphores[self.current_frame]};

        const image_index = @as(u32, @intCast(self.current_image_index.?));

        const present_info = vk.PresentInfoKHR{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(wait_semaphores.ptr),
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&self.swapchain),
            .p_image_indices = @ptrCast(&image_index),
            .p_results = null,
        };

        const result = self.ctx.logical_device.device.queuePresentKHR(self.ctx.present_queue, &present_info) catch {
            log.err("Failed to present vulkan", .{});
            return;
        };

        if (result == .error_out_of_date_khr or result == .suboptimal_khr or self.resized) {
            resize(self, window.get_size_pixels());
            self.resized = false;
        } else if (result != .success) {
            log.err("Swap failed", .{});
            return;
        }
        self.current_frame += 1;
        if (self.current_frame >= MAX_FRAMES_IN_FLIGHT) {
            self.current_frame = 0;
        }
    }

    pub fn get_renderpass(self: Swapchain) vk.RenderPass {
        return self.renderpass;
    }

    pub fn start(self: *const Swapchain) void {
        self.ctx.logical_device.device.resetCommandBuffer(self.command_buffers[self.current_frame], .{}) catch {
            log.err("Failed to reset command buffer", .{});
        };
        const begin_info = vk.CommandBufferBeginInfo{
            .flags = .{},
            .p_inheritance_info = null,
        };

        self.ctx.logical_device.device.beginCommandBuffer(self.command_buffers[self.current_frame], &begin_info) catch {
            log.err("Failed to start command buffer", .{});
            return;
        };

        const clear_color = vk.ClearValue{ .color = .{ .float_32 = .{ 0, 0, 0, 1 } } };

        const pass_info = vk.RenderPassBeginInfo{
            .render_pass = self.renderpass,
            .framebuffer = self.framebuffers[self.current_image_index.?],
            .render_area = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.extent,
            },
            .clear_value_count = 1,
            .p_clear_values = @ptrCast(&clear_color),
        };

        self.ctx.logical_device.device.cmdBeginRenderPass(self.command_buffers[self.current_frame], &pass_info, .@"inline");

        // Update viewport and scissor
        const viewport = vk.Viewport{
            .x = 0,
            .y = @as(f32, @floatFromInt(self.extent.height)),
            .width = @floatFromInt(self.extent.width),
            .height = -@as(f32, @floatFromInt(self.extent.height)),
            .min_depth = 0,
            .max_depth = 1,
        };
        self.ctx.logical_device.device.cmdSetViewport(self.command_buffers[self.current_frame], 0, 1, @ptrCast(&viewport));

        const scissor = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = self.extent,
        };
        self.ctx.logical_device.device.cmdSetScissor(self.command_buffers[self.current_frame], 0, 1, @ptrCast(&scissor));
    }

    pub fn end(self: *const Swapchain) void {
        self.ctx.logical_device.device.cmdEndRenderPass(self.command_buffers[self.current_frame]);

        self.ctx.logical_device.device.endCommandBuffer(self.command_buffers[self.current_frame]) catch {
            log.err("Failed to record command buffer", .{});
            return;
        };

        const wait_semaphores: []const vk.Semaphore = &.{self.image_available_semaphores[self.current_frame]};
        const wait_stages: vk.PipelineStageFlags = .{ .color_attachment_output_bit = true };

        const signal_semaphores: []const vk.Semaphore = &.{self.render_finished_semaphores[self.current_frame]};

        const submit_info = vk.SubmitInfo{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(wait_semaphores.ptr),
            .p_wait_dst_stage_mask = @ptrCast(&wait_stages),
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&self.command_buffers[self.current_frame]),
            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast(signal_semaphores.ptr),
        };

        self.ctx.logical_device.device.queueSubmit(self.ctx.graphics_queue, 1, @ptrCast(&submit_info), self.in_flight_fences[self.current_frame]) catch {
            log.err("Failed to submit command buffer to graphics queue", .{});
        };
    }

    pub fn resize(self: *Swapchain, new_size: @Vector(2, i32)) void {
        self.ctx.logical_device.device.deviceWaitIdle() catch {};

        // Destroy the old framebuffers
        for (self.framebuffers) |framebuffer| {
            self.ctx.logical_device.device.destroyFramebuffer(framebuffer, null);
        }
        std.heap.page_allocator.free(self.framebuffers);

        // Destroy the old swapchain
        recreate(self, new_size) catch {
            log.fatal("Failed to recreate swapchain", .{});
            std.process.exit(1);
        };

        // Create new framebuffers
        self.framebuffers = create_framebuffers(self) catch {
            log.fatal("Failed to recreate framebuffers", .{});
            std.process.exit(1);
        };
    }

    pub fn deinit(self: *const Swapchain) void {
        for (self.framebuffers) |framebuffer| {
            self.ctx.logical_device.device.destroyFramebuffer(framebuffer, null);
        }
        std.heap.page_allocator.free(self.framebuffers);
        self.ctx.logical_device.device.destroyRenderPass(self.renderpass, null);

        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            self.ctx.logical_device.device.destroySemaphore(self.image_available_semaphores[i], null);
            self.ctx.logical_device.device.destroySemaphore(self.render_finished_semaphores[i], null);
            self.ctx.logical_device.device.destroyFence(self.in_flight_fences[i], null);
        }
        for (self.image_views) |view| {
            self.ctx.logical_device.device.destroyImageView(view, null);
        }
        self.allocator.free(self.image_views);
        self.ctx.logical_device.device.destroySwapchainKHR(self.swapchain, null);
        self.allocator.free(self.images);
    }

    pub fn get_current_commandbuffer(self: Swapchain) vk.CommandBuffer {
        return self.command_buffers[self.current_frame];
    }

    pub fn target(self: *const Swapchain) RenderTarget {
        return .{
            .VULKAN = .{
                .SWAPCHAIN = self,
            },
        };
    }
};
