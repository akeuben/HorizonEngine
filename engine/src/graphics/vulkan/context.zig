const std = @import("std");
const log = @import("../../utils/log.zig");
const Window = @import("../../platform/window.zig").Window;
const instance = @import("instance.zig");
const vk = @import("vulkan");
const VulkanExtension = @import("extension.zig").VulkanExtension;
const VulkanLayer = @import("extension.zig").VulkanLayer;
const device = @import("device.zig");
const validation = @import("validation.zig");
const queue = @import("queue.zig");
const swapchain = @import("swapchain.zig");
const VulkanVertexBuffer = @import("buffer.zig").VulkanVertexBuffer;
const VulkanPipeline = @import("shader.zig").VulkanPipeline;
const VulkanRenderTarget = @import("target.zig").VulkanRenderTarget;
const vk_allocator = @import("allocator.zig");
const Context = @import("../context.zig").Context;
const ContextCreationOptions = @import("../context.zig").ContextCreationOptions;

pub const BaseDispatch = vk.BaseWrapper;
pub const InstanceDispatch = vk.InstanceWrapper;
pub const DeviceDispatch = vk.DeviceWrapper;
pub const Instance = vk.InstanceProxy;
pub const Device = vk.DeviceProxy;

pub const VulkanContext = struct {
    loaded: bool = false,
    allocator: std.mem.Allocator,

    creation_options: ContextCreationOptions,

    vkb: BaseDispatch,

    instance: instance.Instance,

    vk_allocator: vk_allocator.VulkanAllocator,

    surface: vk.SurfaceKHR,

    physical_device: device.PhysicalDevice,
    logical_device: device.LogicalDevice,

    graphics_queue: vk.Queue,
    present_queue: vk.Queue,

    swapchain: swapchain.Swapchain,
    command_pool: vk.CommandPool,
    descriptor_pool: vk.DescriptorPool,

    target: VulkanRenderTarget,

    pub fn init(allocator: std.mem.Allocator, options: ContextCreationOptions) *VulkanContext {
        var ctx = allocator.create(VulkanContext) catch unreachable;
        ctx.allocator = allocator;
        ctx.creation_options = options;

        return ctx;
    }

    pub fn load(self: *VulkanContext, window: *const Window) void {
        self.loaded = true;
        log.debug("Loading vulkan base bindings", .{});
        self.vkb = BaseDispatch.load(@as(*const fn (vk.Instance, [*c]const u8) callconv(.C) ?*const fn () callconv(.C) void, @ptrCast(window.get_proc_addr_fn())));
        log.debug("Loaded vulkan base bindings", .{});

        var instance_extensions = std.ArrayList(VulkanExtension).init(self.allocator);
        defer instance_extensions.deinit();

        var device_extensions = std.ArrayList(VulkanExtension).init(self.allocator);
        defer device_extensions.deinit();

        var layers = std.ArrayList(VulkanLayer).init(self.allocator);
        defer layers.deinit();

        const window_instance_extensions = window.get_vk_exts(self.allocator);
        defer self.allocator.free(window_instance_extensions);

        instance_extensions.appendSlice(window_instance_extensions) catch {};
        if (self.creation_options.use_debug) instance_extensions.appendSlice(validation.debug_required_instance_extensions) catch {};

        device_extensions.append(.{
            .name = vk.extensions.khr_swapchain.name,
            .required = true,
        }) catch {};
        device_extensions.append(.{
            .name = vk.extensions.khr_maintenance_1.name,
            .required = true,
        }) catch {};

        if (self.creation_options.use_debug) layers.appendSlice(validation.debug_required_layers) catch {};

        const instance_extension_slice: []VulkanExtension = instance_extensions.toOwnedSlice() catch &.{};
        const device_extension_slice: []VulkanExtension = device_extensions.toOwnedSlice() catch &.{};
        const layer_slice: []VulkanLayer = layers.toOwnedSlice() catch &.{};

        self.instance = instance.Instance.init(self, instance_extension_slice, layer_slice, "Test App", self.allocator) catch {
            log.fatal("Failed to initialize vulkan", .{});
        };
        log.debug("Created vulkan instance", .{});

        self.surface = window.create_vk_surface(self);
        log.debug("Created window surface.", .{});

        self.physical_device = device.PhysicalDevice.init(self, device_extension_slice);
        self.logical_device = device.LogicalDevice.init(self, self.physical_device, layer_slice, device_extension_slice, self.allocator) catch {
            log.fatal("Failed to create logical vulkan device", .{});
        };
        log.debug("Created vulkan logical device", .{});

        self.vk_allocator = vk_allocator.VulkanAllocator.init(self, window);
        log.debug("Created vulkan vk_allocator", .{});

        self.graphics_queue = queue.get_graphics_queue(self, 0);
        self.present_queue = queue.get_present_queue(self, 0);
        log.debug("Created queues", .{});

        const queues = queue.find_queue_families(self, self.physical_device.device) catch {
            log.fatal("Failed to find queue families", .{});
        };

        const command_pool_create_info = vk.CommandPoolCreateInfo{
            .queue_family_index = queues.graphics_family.?,
            .flags = .{ .reset_command_buffer_bit = true },
        };
        self.command_pool = self.logical_device.device.createCommandPool(&command_pool_create_info, null) catch {
            log.fatal("Failed to create command pool", .{});
        };
        log.debug("Created command pool", .{});

        const pool_sizes = [_]vk.DescriptorPoolSize{
            vk.DescriptorPoolSize{
                .type = .uniform_buffer,
                .descriptor_count = 1000 * swapchain.MAX_FRAMES_IN_FLIGHT,
            },
            vk.DescriptorPoolSize{
                .type = .combined_image_sampler,
                .descriptor_count = 1000 * swapchain.MAX_FRAMES_IN_FLIGHT,
            },
        };

        const descriptor_pool_create_info = vk.DescriptorPoolCreateInfo{
            .pool_size_count = @intCast(pool_sizes.len),
            .p_pool_sizes = @ptrCast(&pool_sizes),
            .max_sets = 1000,
        };

        self.descriptor_pool = self.logical_device.device.createDescriptorPool(&descriptor_pool_create_info, null) catch {
            log.fatal("Failed to create descriptor pool.", .{});
        };

        self.swapchain = swapchain.Swapchain.init(self, window, self.allocator) catch {
            log.fatal("Failed to create swapchain", .{});
        };
        log.debug("Created swapchain", .{});

        self.target = .{
            .SWAPCHAIN = &self.swapchain,
        };
        log.debug("Created vulkan default render target", .{});
    }

    pub fn get_target(self: *VulkanContext) VulkanRenderTarget {
        if (!self.loaded) log.fatal("Tried to access a context that has not been loaded!", .{});
        return self.target;
    }

    pub fn notify_resized(self: *VulkanContext) void {
        self.swapchain.resized = true;
    }

    pub fn deinit(self: *VulkanContext) void {
        self.logical_device.device.deviceWaitIdle() catch {};
        self.logical_device.device.destroyDescriptorPool(self.descriptor_pool, null);
        self.logical_device.device.destroyCommandPool(self.command_pool, null);
        self.swapchain.deinit();
        self.vk_allocator.deinit();
        self.logical_device.deinit();

        self.instance.instance.destroySurfaceKHR(self.surface, null);

        self.instance.deinit();

        self.allocator.destroy(self);
    }

    pub fn context(self: *VulkanContext) Context {
        return .{
            .VULKAN = self,
        };
    }
};
