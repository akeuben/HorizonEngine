const std = @import("std");
const log = @import("../../utils/log.zig");
const context = @import("context.zig");
const vk = @import("vulkan");
const device = @import("device.zig");

pub const VulkanExtension = struct {
    name: ?[*:0]const u8,
    required: bool,
};

pub const VulkanLayer = struct {
    name: ?[*:0]const u8,
    required: bool,
};

pub fn get_supported_instance_extensions(ctx: *const context.VulkanContext, requested: []const VulkanExtension) ![]const ?[*:0]const u8 {
    const supported_extension_names = try ctx.vkb.enumerateInstanceExtensionPropertiesAlloc(null, std.heap.page_allocator);

    var supported_extensions = try std.heap.page_allocator.alloc([*:0]const u8, supported_extension_names.len);

    // Create new list of supported extensions
    var actual_extension_count: usize = 0;
    log.debug("Requested extensions: {}", .{requested.len});
    for (requested) |extension| {
        var found = false;
        const extension_length = std.mem.len(extension.name.?);
        for (supported_extension_names) |supported| {
            const supported_name = @as([*:0]const u8, @ptrCast(&supported.extension_name));
            const supported_length = std.mem.len(supported_name);
            if (std.mem.eql(u8, extension.name.?[0..extension_length], supported_name[0..supported_length])) {
                found = true;
                break;
            }
        }

        if (found) {
            log.debug(" [\u{2713}] found extension {s}", .{extension.name.?});
            supported_extensions[actual_extension_count] = extension.name.?;
            actual_extension_count += 1;
        } else if (extension.required) {
            log.err(" [X] Failed to find required extension {s}", .{extension.name.?});
        } else {
            log.warn("  [X] Failed to find optional extension {s}", .{extension.name.?});
        }
    }
    return supported_extensions[0..actual_extension_count];
}

pub fn get_supported_device_extensions(ctx: *const context.VulkanContext, physical_device: vk.PhysicalDevice, requested: []const VulkanExtension) ![]const ?[*:0]const u8 {
    const supported_extension_names = try ctx.instance.instance.enumerateDeviceExtensionPropertiesAlloc(physical_device, null, std.heap.page_allocator);

    var supported_extensions = try std.heap.page_allocator.alloc([*:0]const u8, supported_extension_names.len);

    // Create new list of supported extensions
    var actual_extension_count: usize = 0;
    log.debug("Requested extensions: {}", .{requested.len});
    for (requested) |extension| {
        var found = false;
        const extension_length = std.mem.len(extension.name.?);
        for (supported_extension_names) |supported| {
            const supported_name = @as([*:0]const u8, @ptrCast(&supported.extension_name));
            const supported_length = std.mem.len(supported_name);
            if (std.mem.eql(u8, extension.name.?[0..extension_length], supported_name[0..supported_length])) {
                found = true;
                break;
            }
        }

        if (found) {
            log.debug(" [\u{2713}] found extension {s}", .{extension.name.?});
            supported_extensions[actual_extension_count] = extension.name.?;
            actual_extension_count += 1;
        } else if (extension.required) {
            log.err(" [X] Failed to find required extension {s}", .{extension.name.?});
        } else {
            log.warn("  [X] Failed to find optional extension {s}", .{extension.name.?});
        }
    }
    return supported_extensions[0..actual_extension_count];
}

pub fn get_supported_layers(ctx: *const context.VulkanContext, requested: []const VulkanLayer) ![]const ?[*:0]const u8 {
    const supported_layer_names = try ctx.vkb.enumerateInstanceLayerPropertiesAlloc(std.heap.page_allocator);

    var supported_layers = try std.heap.page_allocator.alloc([*:0]const u8, supported_layer_names.len);

    // Create new list of supported layers
    var actual_layer_count: usize = 0;
    log.debug("Requested layers: {}", .{requested.len});
    for (requested) |layer| {
        var found = false;
        const layer_length = std.mem.len(layer.name.?);
        for (supported_layer_names) |supported| {
            const supported_name = @as([*:0]const u8, @ptrCast(&supported.layer_name));
            const supported_length = std.mem.len(supported_name);
            if (std.mem.eql(u8, layer.name.?[0..layer_length], supported_name[0..supported_length])) {
                found = true;
                break;
            }
        }

        if (found) {
            log.debug(" [\u{2713}] found layer {s}", .{layer.name.?});
            supported_layers[actual_layer_count] = layer.name.?;
            actual_layer_count += 1;
        } else if (layer.required) {
            log.err(" [X] Failed to find required layer {s}", .{layer.name.?});
        } else {
            log.warn("  [X] Failed to find optional layer {s}", .{layer.name.?});
        }
    }
    return supported_layers[0..actual_layer_count];
}
