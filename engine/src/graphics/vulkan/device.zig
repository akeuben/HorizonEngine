const std = @import("std");
const vk = @import("vulkan");
const log = @import("../../utils/log.zig");
const context = @import("./context.zig");
const queue = @import("queue.zig");
const extension = @import("extension.zig");
const swapchain = @import("swapchain.zig");

pub const PhysicalDevice = struct {
    device: vk.PhysicalDevice,

    pub fn init(ctx: *const context.VulkanContext, device_extensions: []extension.VulkanExtension) PhysicalDevice {
        const devices = ctx.instance.instance.enumeratePhysicalDevicesAlloc(std.heap.page_allocator) catch {
            log.fatal("Failed to enumerate physical devices", .{});
            std.process.exit(1);
        };
        defer std.heap.page_allocator.free(devices);

        var highest_score: u32 = 0;
        var highest_device: vk.PhysicalDevice = vk.PhysicalDevice.null_handle;
        for (devices) |device| {
            const score = PhysicalDevice.assign_score(ctx, device, device_extensions);
            if (score > highest_score) {
                highest_score = score;
                highest_device = device;
            }
        }

        if (highest_score == 0 or highest_device == vk.PhysicalDevice.null_handle) {
            log.fatal("Failed to find a suitable physical device for vulkan instance", .{});
        }

        return PhysicalDevice{
            .device = highest_device,
        };
    }

    pub fn assign_score(ctx: *const context.VulkanContext, device: vk.PhysicalDevice, device_extensions: []extension.VulkanExtension) u32 {
        var score: u32 = 0;
        const properties = ctx.instance.instance.getPhysicalDeviceProperties(device);
        score += switch (properties.device_type) {
            .discrete_gpu => 1000,
            .integrated_gpu => 100,
            .virtual_gpu => 10,
            else => 0,
        };

        // Check required parameters
        const queue_families = queue.find_queue_families(ctx, device) catch {
            log.warn("Failed to find queue families for device {s}. Assigning a score of 0", .{properties.device_name});
            return 0;
        };

        if (!queue_families.is_complete()) {
            log.warn("Incomplete queue family for device {s}. Assigning a score of 0", .{properties.device_name});
            return 0;
        }

        const supported_extensions = extension.get_supported_device_extensions(ctx, device, device_extensions) catch {
            log.warn("Failed to find supported extensions for device {s}. Assigning a score of 0", .{properties.device_name});
            return 0;
        };

        if (supported_extensions.len != device_extensions.len) {
            log.warn("Device {s} does not support required extensions. Assigning a score of 0", .{properties.device_name});
            return 0;
        }

        const physcial_features = ctx.instance.instance.getPhysicalDeviceFeatures(device);

        if(physcial_features.sampler_anisotropy == vk.FALSE) {
            log.warn("Device {s} does not support sampler anisotropy. Assigning a score of 0", .{properties.device_name});
        }

        const swapchain_support = swapchain.query_swapchain_support(ctx, device, ctx.surface, std.heap.page_allocator) catch {
            log.warn("Failed to query swapchain support for device {s}. Assigning a score of 0", .{properties.device_name});
            return 0;
        };
        defer swapchain_support.deinit();

        if (swapchain_support.formats.len == 0 or swapchain_support.present_modes.len == 0) {
            log.debug("Device {s} does not have a valid swapchain available. Assigning a score of 0", .{properties.device_name});
            return 0;
        }

        log.debug("Assigned device {s} the score {}", .{ properties.device_name, score });

        return score;
    }
};

pub const LogicalDevice = struct {
    device: context.Device,
    vkd: *context.DeviceDispatch,
    allocator: std.mem.Allocator,

    pub fn init(ctx: *const context.VulkanContext, physical_device: PhysicalDevice, layers: []const extension.VulkanLayer, extensions: []extension.VulkanExtension, allocator: std.mem.Allocator) !LogicalDevice {
        // Create Queues
        const queue_families = try queue.find_queue_families(ctx, physical_device.device);

        var unique_queue_families: [std.meta.fields(@TypeOf(queue_families)).len]u32 = undefined;
        var unique_queue_family_count: usize = 0;
        inline for (std.meta.fields(@TypeOf(queue_families))) |field| {
            const family_index = @as(?u32, @field(queue_families, field.name));
            var found: bool = false;
            for (0..unique_queue_family_count) |family| {
                if (unique_queue_families[family] == family_index.?) {
                    found = true;
                    break;
                }
            }

            if (found) break;

            unique_queue_families[unique_queue_family_count] = family_index.?;
            unique_queue_family_count += 1;
        }

        log.debug("Found {} unique families", .{unique_queue_family_count});

        const queue_priority: f32 = 1.0;

        var queue_create_infos = try std.ArrayList(vk.DeviceQueueCreateInfo).initCapacity(std.heap.page_allocator, unique_queue_family_count);
        defer queue_create_infos.deinit();

        for (0..unique_queue_family_count) |i| {
            queue_create_infos.append(.{
                .queue_family_index = unique_queue_families[i],
                .queue_count = 1,
                .p_queue_priorities = @ptrCast(&queue_priority),
            }) catch {};
        }

        const queue_create_info = try queue_create_infos.toOwnedSlice();

        const physical_device_features = vk.PhysicalDeviceFeatures{
            .sampler_anisotropy = vk.TRUE,
        };

        const supported_layers = try extension.get_supported_layers(ctx, layers);
        const supported_extensions = try extension.get_supported_device_extensions(ctx, physical_device.device, extensions);

        const dynamic_rendering_feature = vk.PhysicalDeviceDynamicRenderingFeatures {
            .dynamic_rendering = vk.TRUE,
        };
        
        const create_info = vk.DeviceCreateInfo{
            .p_queue_create_infos = @ptrCast(queue_create_info.ptr),
            .queue_create_info_count = @intCast(queue_create_info.len),
            .p_enabled_features = &physical_device_features,
            .pp_enabled_layer_names = @ptrCast(supported_layers.ptr),
            .enabled_layer_count = @intCast(supported_layers.len),
            .pp_enabled_extension_names = @ptrCast(supported_extensions.ptr),
            .enabled_extension_count = @intCast(supported_extensions.len),
            .p_next = &dynamic_rendering_feature,
        };

        const vk_device = try ctx.instance.instance.createDevice(physical_device.device, &create_info, null);

        const vkd = try allocator.create(context.DeviceDispatch);
        vkd.* = context.DeviceDispatch.load(vk_device, ctx.instance.instance.wrapper.dispatch.vkGetDeviceProcAddr.?);
        const device = context.Device.init(vk_device, vkd);

        return LogicalDevice{
            .device = device,
            .vkd = vkd,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: LogicalDevice) void {
        self.device.destroyDevice(null);
        self.allocator.destroy(self.vkd);
    }
};
