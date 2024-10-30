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
const SwapchainVulkanRenderTarget = @import("target.zig").SwapchainVulkanRenderTarget;

const apis: []const vk.ApiInfo = &.{
    vk.features.version_1_0,
    vk.extensions.ext_debug_utils,
    vk.extensions.khr_surface,
    vk.extensions.khr_swapchain,
};
pub const BaseDispatch = vk.BaseWrapper(apis);
pub const InstanceDispatch = vk.InstanceWrapper(apis);
pub const DeviceDispatch = vk.DeviceWrapper(apis);
pub const Instance = vk.InstanceProxy(apis);
pub const Device = vk.DeviceProxy(apis);

pub const VulkanContext = struct {
    loaded: bool = false,

    vkb: BaseDispatch,

    instance: instance.Instance,

    surface: vk.SurfaceKHR,

    physical_device: device.PhysicalDevice,
    logical_device: device.LogicalDevice,

    graphics_queue: vk.Queue,
    present_queue: vk.Queue,

    swapchain: swapchain.Swapchain,
    target: VulkanRenderTarget,
    command_pool: vk.CommandPool,

    pub fn init() VulkanContext {
        return undefined;
    }

    pub fn load(self: *VulkanContext, window: *const Window) void {
        self.loaded = true;
        log.debug("Loading vulkan base bindings", .{});
        self.vkb = BaseDispatch.load(@as(*const fn (vk.Instance, [*c]const u8) callconv(.C) ?*const fn () callconv(.C) void, @ptrCast(window.get_proc_addr_fn()))) catch {
            log.fatal("Failed to load vulkan bindings", .{});
            std.process.exit(1);
        };
        log.debug("Loaded vulkan base bindings", .{});

        var instance_extensions = std.ArrayList(VulkanExtension).init(std.heap.page_allocator);
        defer instance_extensions.deinit();

        var device_extensions = std.ArrayList(VulkanExtension).init(std.heap.page_allocator);
        defer device_extensions.deinit();

        var layers = std.ArrayList(VulkanLayer).init(std.heap.page_allocator);
        defer layers.deinit();

        const glfw_instance_extensions = window.get_vk_exts();
        defer std.heap.page_allocator.free(glfw_instance_extensions);

        instance_extensions.appendSlice(glfw_instance_extensions) catch {};
        instance_extensions.appendSlice(validation.debug_required_instance_extensions) catch {};
        instance_extensions.append(.{
            .name = vk.extensions.khr_surface.name,
            .required = true,
        }) catch {};

        device_extensions.append(.{
            .name = vk.extensions.khr_swapchain.name,
            .required = true,
        }) catch {};
        device_extensions.append(.{
            .name = vk.extensions.khr_maintenance_1.name,
            .required = true,
        }) catch {};

        layers.appendSlice(validation.debug_required_layers) catch {};

        const instance_extension_slice: []VulkanExtension = instance_extensions.toOwnedSlice() catch &.{};
        const device_extension_slice: []VulkanExtension = device_extensions.toOwnedSlice() catch &.{};
        const layer_slice: []VulkanLayer = layers.toOwnedSlice() catch &.{};

        self.instance = instance.Instance.init(self, instance_extension_slice, layer_slice, "Test App", std.heap.page_allocator) catch {
            log.fatal("Failed to initialize vulkan", .{});
            std.process.exit(1);
        };
        log.debug("Created vulkan instance", .{});

        self.surface = window.create_vk_surface(self);
        log.debug("Created window surface.", .{});

        self.physical_device = device.PhysicalDevice.init(self, device_extension_slice);
        self.logical_device = device.LogicalDevice.init(self, self.physical_device, layer_slice, device_extension_slice, std.heap.page_allocator) catch {
            log.fatal("Failed to create logical vulkan device", .{});
            std.process.exit(1);
        };
        log.debug("Created vulkan logical device", .{});

        self.graphics_queue = queue.get_graphics_queue(self, 0);
        self.present_queue = queue.get_present_queue(self, 0);
        log.debug("Created queues", .{});

        self.swapchain = swapchain.Swapchain.init(self, window, std.heap.page_allocator) catch {
            log.fatal("Failed to create swapchain", .{});
            std.process.exit(1);
        };
        log.debug("Created swapchain", .{});

        const queues = queue.find_queue_families(self, self.physical_device.device) catch {
            log.fatal("Failed to find queue families", .{});
            std.process.exit(1);
        };

        const command_pool_create_info = vk.CommandPoolCreateInfo{
            .queue_family_index = queues.graphics_family.?,
            .flags = .{ .reset_command_buffer_bit = true },
        };
        self.command_pool = self.logical_device.device.createCommandPool(&command_pool_create_info, null) catch {
            log.fatal("Failed to create command pool", .{});
            std.process.exit(1);
        };
        log.debug("Created command pool", .{});

        self.target = VulkanRenderTarget{
            .DEFAULT = SwapchainVulkanRenderTarget.init(self, std.heap.page_allocator) catch {
                log.fatal("Failed to create default render target", .{});
                std.process.exit(1);
            },
        };
        log.debug("Created vulkan default render target", .{});
    }

    pub fn get_target(self: *VulkanContext) *VulkanRenderTarget {
        if (!self.loaded) log.fatal("Tried to access a context that has not been loaded!", .{});
        return &self.target;
    }

    pub fn notify_resized(self: *VulkanContext) void {
        self.swapchain.resized = true;
    }

    pub fn deinit(self: VulkanContext) void {
        self.logical_device.device.deviceWaitIdle() catch {};
        self.target.deinit(&self);
        self.logical_device.device.destroyCommandPool(self.command_pool, null);
        self.swapchain.deinit(&self);
        self.logical_device.deinit();

        self.instance.instance.destroySurfaceKHR(self.surface, null);

        self.instance.deinit();
    }
};
