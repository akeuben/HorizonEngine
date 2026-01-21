const std = @import("std");
const vk = @import("vulkan");
const Window = @import("../../platform/window.zig").Window;
const context = @import("./context.zig");
const log = @import("../../utils/log.zig");
const extension = @import("extension.zig");
const validation = @import("validation.zig");

pub const Instance = struct {
    instance: context.Instance,
    vki: *context.InstanceDispatch,
    debug_messenger: ?vk.DebugUtilsMessengerEXT,
    allocator: std.mem.Allocator,

    pub fn init(ctx: *const context.VulkanContext, extensions: []const extension.VulkanExtension, layers: []const extension.VulkanLayer, name: ?[*:0]const u8, allocator: std.mem.Allocator) !Instance {
        const app_info = vk.ApplicationInfo{
            .p_application_name = name,
            .application_version = @bitCast(vk.makeApiVersion(1, 0, 0, 0)),
            .p_engine_name = "engine",
            .engine_version = @bitCast(vk.makeApiVersion(1, 0, 0, 0)),
            .api_version = @bitCast(vk.API_VERSION_1_3),
            .p_next = null,
        };

        const supported_extensions = try extension.get_supported_instance_extensions(ctx, extensions);
        defer ctx.allocator.free(supported_extensions);

        const supported_layers = try extension.get_supported_layers(ctx, layers);
        defer ctx.allocator.free(supported_layers);

        var create_info = vk.InstanceCreateInfo{
            .p_application_info = &app_info,
            .enabled_extension_count = @intCast(supported_extensions.len),
            .pp_enabled_extension_names = @ptrCast(supported_extensions),
            .enabled_layer_count = @intCast(supported_layers.len),
            .pp_enabled_layer_names = @ptrCast(supported_layers),
            .p_next = null,
        };
        if (ctx.creation_options.use_debug) {
            log.debug("Loading debug extension for instance creation...", .{});
            create_info.p_next = &validation.debugCreateInfo;
        }
        const vk_instance = try ctx.vkb.createInstance(&create_info, null);

        const vki = try allocator.create(context.InstanceDispatch);
        vki.* = context.InstanceDispatch.load(vk_instance, ctx.vkb.dispatch.vkGetInstanceProcAddr.?);
        const instance = context.Instance.init(vk_instance, vki);

        var debug_messenger: vk.DebugUtilsMessengerEXT = .null_handle;
        if (ctx.creation_options.use_debug) {
            log.debug("Using debug: True", .{});
            debug_messenger = instance.createDebugUtilsMessengerEXT(&validation.debugCreateInfo, null) catch blk: {
                log.warn("Failed to create debug messenger", .{});
                break :blk vk.DebugUtilsMessengerEXT.null_handle;
            };
        } else {
            log.debug("Using debug: False", .{});
        }

        return Instance{
            .instance = instance,
            .vki = vki,
            .debug_messenger = debug_messenger,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Instance) void {
        if (self.debug_messenger != vk.DebugUtilsMessengerEXT.null_handle) self.instance.destroyDebugUtilsMessengerEXT(self.debug_messenger.?, null);
        self.instance.destroyInstance(null);
    }
};
