const std = @import("std");
const vk = @import("vulkan");
const context = @import("context.zig");
const Window = @import("../../platform/window.zig").Window;
const queue = @import("queue.zig");
const device = @import("device.zig");
const log = @import("../../utils/log.zig");

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

fn choose_swap_extent(window: *const Window, capabilities: *const vk.SurfaceCapabilitiesKHR) vk.Extent2D {
    if (capabilities.current_extent.width != std.math.maxInt(u32)) {
        return capabilities.current_extent;
    }

    const size = window.get_size_pixels();

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

pub const Swapchain = struct {
    swapchain: vk.SwapchainKHR,
    images: []vk.Image,
    image_views: []vk.ImageView,
    format: vk.Format,
    extent: vk.Extent2D,
    current_image_index: ?usize,
    in_flight_fence: vk.Fence,
    image_available_semaphore: vk.Semaphore,
    render_finished_semaphore: vk.Semaphore,
    allocator: std.mem.Allocator,

    pub fn init(ctx: *const context.VulkanContext, window: *const Window, allocator: std.mem.Allocator) !Swapchain {
        const support = try query_swapchain_support(ctx, ctx.physical_device.device, ctx.surface, std.heap.page_allocator);
        defer support.deinit();

        const format = choose_swapchain_format(support.formats);
        const present_mode = choose_swapchain_present_mode(support.present_modes);
        const extent = choose_swap_extent(window, &support.capabilities);

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

        const swapchain = try ctx.logical_device.device.createSwapchainKHR(&create_info, null);

        const images = try ctx.logical_device.device.getSwapchainImagesAllocKHR(swapchain, allocator);

        const image_views = try allocator.alloc(vk.ImageView, images.len);
        for (images, 0..) |image, i| {
            const view_create_info: vk.ImageViewCreateInfo = .{
                .image = image,
                .view_type = .@"2d",
                .format = format.format,
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

        const fence = try ctx.logical_device.device.createFence(&vk.FenceCreateInfo{
            .flags = .{ .signaled_bit = true },
        }, null);
        const image_semaphore = try ctx.logical_device.device.createSemaphore(&.{}, null);
        const render_semaphore = try ctx.logical_device.device.createSemaphore(&.{}, null);

        return Swapchain{
            .swapchain = swapchain,
            .images = images,
            .format = format.format,
            .extent = extent,
            .image_views = image_views,
            .current_image_index = null,
            .in_flight_fence = fence,
            .image_available_semaphore = image_semaphore,
            .render_finished_semaphore = render_semaphore,
            .allocator = allocator,
        };
    }

    pub fn aquire_image(self: *Swapchain, ctx: *const context.VulkanContext) void {
        _ = ctx.logical_device.device.waitForFences(1, @ptrCast(&self.in_flight_fence), vk.TRUE, std.math.maxInt(u64)) catch {
            log.err("Failed to wait for previous frame to finish!", .{});
            return undefined;
        };
        ctx.logical_device.device.resetFences(1, @ptrCast(&self.in_flight_fence)) catch {
            log.err("Failed to reset previous frame fence", .{});
        };

        const result = ctx.logical_device.device.acquireNextImageKHR(self.swapchain, std.math.maxInt(u64), self.image_available_semaphore, .null_handle) catch null;
        self.current_image_index = if (result != null and result.?.result == .success) result.?.image_index else null;
        log.debug("Aquired swapchain image {}", .{self.current_image_index.?});
    }

    pub fn swap(self: Swapchain, ctx: *const context.VulkanContext) void {
        const wait_semaphores: []const vk.Semaphore = &.{self.render_finished_semaphore};

        const image_index = @as(u32, @intCast(self.current_image_index.?));
        log.debug("Image index: {}", .{image_index});

        const present_info = vk.PresentInfoKHR{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(wait_semaphores.ptr),
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&self.swapchain),
            .p_image_indices = @ptrCast(&image_index),
            .p_results = null,
        };

        _ = ctx.logical_device.device.queuePresentKHR(ctx.present_queue, &present_info) catch {
            log.err("Failed to present vulkan", .{});
        };
    }

    pub fn deinit(self: Swapchain, ctx: *const context.VulkanContext) void {
        ctx.logical_device.device.destroySemaphore(self.image_available_semaphore, null);
        ctx.logical_device.device.destroySemaphore(self.render_finished_semaphore, null);
        ctx.logical_device.device.destroyFence(self.in_flight_fence, null);
        for (self.image_views) |view| {
            ctx.logical_device.device.destroyImageView(view, null);
        }
        self.allocator.free(self.image_views);
        self.allocator.free(self.images);
        ctx.logical_device.device.destroySwapchainKHR(self.swapchain, null);
    }
};
