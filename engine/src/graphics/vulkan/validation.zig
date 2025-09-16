const std = @import("std");
const log = @import("../../utils/log.zig");
const extension = @import("extension.zig");
const vk = @import("vulkan");

fn vk_error_callback(severity: vk.DebugUtilsMessageSeverityFlagsEXT, message_type: vk.DebugUtilsMessageTypeFlagsEXT, data: ?*const vk.DebugUtilsMessengerCallbackDataEXT, _: ?*anyopaque) callconv(.c) vk.Bool32 {
    if (severity.error_bit_ext) log.err("VK {}: {s}", .{ message_type.toInt(), data.?.p_message.? });
    if (severity.warning_bit_ext) log.warn("VK {}: {s}", .{ message_type.toInt(), data.?.p_message.? });
    if (severity.info_bit_ext) log.info("VK {}: {s}", .{ message_type.toInt(), data.?.p_message.? });
    if (severity.verbose_bit_ext) log.debug("VK {}: {s}", .{ message_type.toInt(), data.?.p_message.? });
    return .false;
}

pub const debugCreateInfo: vk.DebugUtilsMessengerCreateInfoEXT = .{
    .message_severity = .{
        .error_bit_ext = true,
        .warning_bit_ext = true,
        .info_bit_ext = true,
        .verbose_bit_ext = true,
    },
    .message_type = .{
        .general_bit_ext = true,
        .validation_bit_ext = true,
        .performance_bit_ext = true,
    },
    .pfn_user_callback = &vk_error_callback,
    .p_user_data = null,
};

pub const debug_required_instance_extensions: []const extension.VulkanExtension = &.{.{
    .name = vk.extensions.ext_debug_utils.name,
    .required = false,
}};

pub const debug_required_layers: []const extension.VulkanLayer = &.{
    .{
        .name = @ptrCast("VK_LAYER_KHRONOS_validation"),
        .required = false,
    },
};
