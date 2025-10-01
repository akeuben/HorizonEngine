const std = @import("std");
const log = @import("../../utils/log.zig");
const VulkanContext = @import("./context.zig").VulkanContext;
const Window = @import("../../platform/window.zig").Window;
const vk = @import("vulkan");
const vma = @cImport({
    @cDefine("VMA_STATIC_VULKAN_FUNCTIONS", "0");
    @cDefine("VMA_DYNAMIC_VULKAN_FUNCTIONS", "1");
    @cDefine("VMA_VULKAN_VERSION", "1000000");
    @cInclude("vulkan/vulkan.h");
    @cInclude("vk_mem_alloc.h");
});

fn vk_properties_to_vma_flags(properties: vk.MemoryPropertyFlags) c_uint {
    var result: c_uint = 0;

    if (properties.host_visible_bit) {
        result |= vma.VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT;
    }

    return result;
}

pub const AllocatedVulkanBuffer = struct {
    buffer: vma.VkBuffer,
    memory: vma.VmaAllocation,

    pub inline fn asVulkanBuffer(self: AllocatedVulkanBuffer) vk.Buffer {
        return @enumFromInt(@intFromPtr(self.buffer));
    }
};

pub const AllocatedVulkanImage = struct {
    image: vma.VkImage,
    memory: vma.VmaAllocation,

    pub inline fn asVulkanImage(self: AllocatedVulkanImage) vk.Image {
        return @enumFromInt(@intFromPtr(self.image));
    }
};
pub const VulkanAllocator = struct {
    allocator: vma.VmaAllocator,

    pub fn init(ctx: *VulkanContext, window: *const Window) VulkanAllocator {
        const vulkan_functions = vma.VmaVulkanFunctions{
            .vkGetInstanceProcAddr = @ptrCast(window.get_proc_addr_fn()),
            .vkGetDeviceProcAddr = @ptrCast(ctx.instance.instance.wrapper.dispatch.vkGetDeviceProcAddr),
        };
        const create_info = vma.VmaAllocatorCreateInfo{
            .instance = @ptrFromInt(@intFromEnum(ctx.instance.instance.handle)),
            .device = @ptrFromInt(@intFromEnum(ctx.logical_device.device.handle)),
            .vulkanApiVersion = vma.VK_API_VERSION_1_0,
            .physicalDevice = @ptrFromInt(@intFromEnum(ctx.physical_device.device)),
            .pVulkanFunctions = @ptrCast(&vulkan_functions),
        };
        var allocator: vma.VmaAllocator = undefined;
        const result: vma.VkResult = vma.vmaCreateAllocator(&create_info, &allocator);
        if (result != vma.VK_SUCCESS) {
            log.fatal("Failed to create vulkan allocator", .{});
            std.process.exit(1);
        }
        return VulkanAllocator{
            .allocator = allocator,
        };
    }

    pub fn create_buffer(self: *const VulkanAllocator, size: vk.DeviceSize, usage: vk.BufferUsageFlags, properties: vk.MemoryPropertyFlags) AllocatedVulkanBuffer {
        const buffer_create_info = vma.VkBufferCreateInfo{
            .sType = vma.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = size,
            .usage = @intCast(usage.toInt()),
            .sharingMode = vma.VK_SHARING_MODE_EXCLUSIVE,
        };

        const alloc_info = vma.VmaAllocationCreateInfo{
            .usage = vma.VMA_MEMORY_USAGE_AUTO,
            .flags = vk_properties_to_vma_flags(properties),
        };

        var buffer: vma.VkBuffer = undefined;
        var memory: vma.VmaAllocation = undefined;
        const result = vma.vmaCreateBuffer(self.allocator, @ptrCast(&buffer_create_info), @ptrCast(&alloc_info), @ptrCast(&buffer), @ptrCast(&memory), null);

        if (result != vma.VK_SUCCESS) {
            log.fatal("Failed to create vulkan buffer", .{});
        }

        return AllocatedVulkanBuffer{
            .buffer = buffer,
            .memory = memory,
        };
    }

    pub fn create_image(self: *const VulkanAllocator, extent: vk.Extent3D, format: vk.Format, tiling: vk.ImageTiling, usage: vk.ImageUsageFlags, properties: vk.MemoryPropertyFlags) AllocatedVulkanImage {
        const image_create_info = vma.VkImageCreateInfo{
            .sType = vma.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            .imageType = vma.VK_IMAGE_TYPE_2D,
            .extent = .{
                .width = extent.width,
                .height = extent.height,
                .depth = extent.depth,
            },
            .mipLevels = 1,
            .arrayLayers = 1,
            .format = @intCast(@intFromEnum(format)),
            .tiling = @intCast(@intFromEnum(tiling)),
            .initialLayout = vma.VK_IMAGE_LAYOUT_UNDEFINED,
            .usage = usage.toInt(),
            .sharingMode = vma.VK_SHARING_MODE_EXCLUSIVE,
            .samples = vma.VK_SAMPLE_COUNT_1_BIT,
        };

        const alloc_info = vma.VmaAllocationCreateInfo{
            .usage = vma.VMA_MEMORY_USAGE_AUTO,
            .flags = vk_properties_to_vma_flags(properties),
        };

        var image: vma.VkImage = undefined;
        var memory: vma.VmaAllocation = undefined;

        const result = vma.vmaCreateImage(self.allocator, @ptrCast(&image_create_info), @ptrCast(&alloc_info), @ptrCast(&image), @ptrCast(&memory), null);

        if(result != vma.VK_SUCCESS) {
            log.fatal("Failed to create vulkan image", .{});
        }

        return AllocatedVulkanImage{
            .image = image,
            .memory = memory,
        };
    }

    pub fn map_buffer(self: *const VulkanAllocator, comptime T: anytype, buffer: AllocatedVulkanBuffer) *T {
        var ptr: *anyopaque = undefined;
        const result = vma.vmaMapMemory(self.allocator, buffer.memory, @ptrCast(&ptr));
        if (result != vma.VK_SUCCESS) {
            log.err("Failed to map buffer memory", .{});
        }
        return @as(*T, @alignCast(@ptrCast(ptr)));
    }

    pub fn unmap_buffer(self: *const VulkanAllocator, buffer: AllocatedVulkanBuffer) void {
        vma.vmaUnmapMemory(self.allocator, buffer.memory);
    }

    pub fn destroy_buffer(self: *const VulkanAllocator, buffer: AllocatedVulkanBuffer) void {
        vma.vmaDestroyBuffer(self.allocator, buffer.buffer, buffer.memory);
    }

    pub fn destroy_image(self: *const VulkanAllocator, image: AllocatedVulkanImage) void {
        vma.vmaDestroyImage(self.allocator, image.image, image.memory);
    }

    pub fn deinit(self: VulkanAllocator) void {
        vma.vmaDestroyAllocator(
            self.allocator,
        );
    }
};
