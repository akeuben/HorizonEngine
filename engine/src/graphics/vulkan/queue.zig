const std = @import("std");
const log = @import("../../utils/log.zig");
const context = @import("./context.zig");
const vk = @import("vulkan");

pub const QueueFamilyIndices = struct {
    graphics_family: ?u32,
    present_family: ?u32,

    pub fn is_complete(self: QueueFamilyIndices) bool {
        return self.graphics_family != null and self.present_family != null;
    }
};

pub fn find_queue_families(ctx: *const context.VulkanContext, physical_device: vk.PhysicalDevice) !QueueFamilyIndices {
    var queue_family_indices: QueueFamilyIndices = undefined;

    const queue_families = try ctx.instance.instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(physical_device, ctx.allocator);
    defer ctx.allocator.free(queue_families);

    for (queue_families, 0..) |family, i| {
        if (family.queue_flags.graphics_bit) {
            queue_family_indices.graphics_family = @intCast(i);
        }

        if (try ctx.instance.instance.getPhysicalDeviceSurfaceSupportKHR(physical_device, @intCast(i), ctx.surface) == .true) {
            queue_family_indices.present_family = @intCast(i);
        }

        if (queue_family_indices.is_complete()) break;
    }

    return queue_family_indices;
}

pub fn get_graphics_queue(ctx: *const context.VulkanContext, index: u32) vk.Queue {
    const indices = find_queue_families(ctx, ctx.physical_device.device) catch unreachable;
    const queue = ctx.logical_device.device.getDeviceQueue(indices.graphics_family.?, index);
    return queue;
}

pub fn get_present_queue(ctx: *const context.VulkanContext, index: u32) vk.Queue {
    const indices = find_queue_families(ctx, ctx.physical_device.device) catch unreachable;
    const queue = ctx.logical_device.device.getDeviceQueue(indices.present_family.?, index);
    return queue;
}
