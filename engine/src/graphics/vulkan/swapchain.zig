const std = @import("std");
const vk = @import("vulkan");
const context = @import("context.zig");
const Window = @import("../../platform/window.zig").Window;
const queue = @import("queue.zig");
const device = @import("device.zig");
const log = @import("../../utils/log.zig");
const SwapchainVulkanRenderTarget = @import("target.zig").SwapchainVulkanRenderTarget;

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
    resized: bool,
    allocator: std.mem.Allocator,

    pub fn init(ctx: *const context.VulkanContext, window: *const Window, allocator: std.mem.Allocator) !Swapchain {
        var swapchain: Swapchain = undefined;
        swapchain.current_image_index = null;
        swapchain.current_frame = 0;
        swapchain.allocator = allocator;
        swapchain.resized = false;

        try create_swapchain(&swapchain, ctx, window.get_size_pixels());
        try create_image_views(&swapchain, ctx);

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

        return swapchain;
    }

    fn create_swapchain(self: *Swapchain, ctx: *const context.VulkanContext, size: @Vector(2, i32)) !void {
        const support = try query_swapchain_support(ctx, ctx.physical_device.device, ctx.surface, std.heap.page_allocator);
        defer support.deinit();

        const format = choose_swapchain_format(support.formats);
        const present_mode = choose_swapchain_present_mode(support.present_modes);
        const extent = choose_swap_extent(size, &support.capabilities);

        var image_count: u32 = support.capabilities.min_image_count + 1;
        if (support.capabilities.max_image_count > 0 and image_count > support.capabilities.max_image_count) {
            image_count = support.capabilities.max_image_count;
        }

        const indices = try queue.find_queue_families(ctx, ctx.physical_device.device);
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
            .surface = ctx.surface,
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
            .old_swapchain = .null_handle,
        };

        self.swapchain = try ctx.logical_device.device.createSwapchainKHR(&create_info, null);
        self.format = format.format;
        self.extent = extent;
    }

    fn create_image_views(self: *Swapchain, ctx: *const context.VulkanContext) !void {
        const images = try ctx.logical_device.device.getSwapchainImagesAllocKHR(self.swapchain, self.allocator);

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
            image_views[i] = try ctx.logical_device.device.createImageView(&view_create_info, null);
        }

        self.images = images;
        self.image_views = image_views;
    }

    pub fn recreate(self: *Swapchain, ctx: *const context.VulkanContext, size: @Vector(2, i32)) !void {
        ctx.logical_device.device.deviceWaitIdle() catch {};

        for (self.image_views) |view| {
            ctx.logical_device.device.destroyImageView(view, null);
        }
        ctx.logical_device.device.destroySwapchainKHR(self.swapchain, null);

        try create_swapchain(self, ctx, size);
        try create_image_views(self, ctx);
    }

    pub fn acquire_image(self: *Swapchain, ctx: *const context.VulkanContext) AcquireImageError!void {
        const r = ctx.logical_device.device.waitForFences(1, @ptrCast(&self.in_flight_fences[self.current_frame]), vk.TRUE, std.math.maxInt(u64)) catch {
            log.err("Failed to wait for previous frame to finish!", .{});
            return undefined;
        };

        if (r != .success) {
            log.err("Failed to wait for previous frame to finish!", .{});
        }

        const result = ctx.logical_device.device.acquireNextImageKHR(self.swapchain, std.math.maxInt(u64), self.image_available_semaphores[self.current_frame], .null_handle) catch {
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

        ctx.logical_device.device.resetFences(1, @ptrCast(&self.in_flight_fences[self.current_frame])) catch {
            log.err("Failed to reset previous frame fence", .{});
        };

        self.current_image_index = result.image_index;
    }

    pub fn swap(self: *Swapchain, ctx: *context.VulkanContext, window: *const Window) void {
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

        const result = ctx.logical_device.device.queuePresentKHR(ctx.present_queue, &present_info) catch {
            log.err("Failed to present vulkan", .{});
            return;
        };

        if (result == .error_out_of_date_khr or result == .suboptimal_khr or self.resized) {
            SwapchainVulkanRenderTarget.resize(ctx.target.DEFAULT, ctx, window.get_size_pixels());
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

    pub fn deinit(self: Swapchain, ctx: *const context.VulkanContext) void {
        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            ctx.logical_device.device.destroySemaphore(self.image_available_semaphores[i], null);
            ctx.logical_device.device.destroySemaphore(self.render_finished_semaphores[i], null);
            ctx.logical_device.device.destroyFence(self.in_flight_fences[i], null);
        }
        for (self.image_views) |view| {
            ctx.logical_device.device.destroyImageView(view, null);
        }
        self.allocator.free(self.image_views);
        self.allocator.free(self.images);
        ctx.logical_device.device.destroySwapchainKHR(self.swapchain, null);
    }
};
