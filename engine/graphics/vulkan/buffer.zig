const std = @import("std");
const types = @import("../type.zig");
const vk = @import("vulkan");
const log = @import("../../utils/log.zig");
const context = @import("context.zig");

fn find_memory_type(ctx: *const context.VulkanContext, type_filter: u32, properties: vk.MemoryPropertyFlags) u32 {
    const memory_properties = ctx.instance.instance.getPhysicalDeviceMemoryProperties(ctx.physical_device.device);
    for (0..memory_properties.memory_type_count) |i| {
        if ((type_filter & (@as(u32, @intCast(1)) << @as(u5, @intCast(i)))) != 0 and (memory_properties.memory_types[i].property_flags.toInt() & properties.toInt()) == properties.toInt()) {
            return @intCast(i);
        }
    }

    log.fatal("Unable to find memory for buffer allocation", .{});
    std.process.exit(1);
}

pub const VulkanVertexBuffer = struct {
    layout: types.BufferLayout,
    vk_buffer: vk.Buffer,
    buffer_memory: ?vk.DeviceMemory,

    pub fn init(ctx: *const context.VulkanContext, comptime T: anytype, data: []const T) VulkanVertexBuffer {
        const layout = types.generate_layout(T, data) catch {
            log.fatal("Failed to generate layout of vertex buffer", .{});
            unreachable;
        };

        var buffer = VulkanVertexBuffer{
            .layout = layout,
            .buffer_memory = null,
            .vk_buffer = undefined,
        };

        buffer.set_data(ctx, T, data);

        return buffer;
    }

    pub fn set_data(self: *VulkanVertexBuffer, ctx: *const context.VulkanContext, comptime T: anytype, data: []const T) void {
        if (self.buffer_memory != null) {
            self.deinit(ctx);
        }
        const create_info = vk.BufferCreateInfo{
            .size = self.layout.size * data.len,
            .usage = .{ .vertex_buffer_bit = true },
            .sharing_mode = .exclusive,
        };

        self.vk_buffer = ctx.logical_device.device.createBuffer(&create_info, null) catch {
            log.fatal("Failed to create vulkan buffer", .{});
            std.process.exit(1);
        };

        const memory_requirements = ctx.logical_device.device.getBufferMemoryRequirements(self.vk_buffer);
        const alloc_info = vk.MemoryAllocateInfo{
            .allocation_size = memory_requirements.size,
            .memory_type_index = find_memory_type(
                ctx,
                memory_requirements.memory_type_bits,
                vk.MemoryPropertyFlags{
                    .host_visible_bit = true,
                    .host_cached_bit = true,
                },
            ),
        };

        self.buffer_memory = ctx.logical_device.device.allocateMemory(&alloc_info, null) catch {
            log.fatal("Failed to allocate memory for vertex buffer", .{});
            std.process.exit(1);
        };

        ctx.logical_device.device.bindBufferMemory(self.vk_buffer, self.buffer_memory.?, 0) catch {
            log.fatal("Failed to bind memory for vertex buffer", .{});
            std.process.exit(1);
        };

        const map_ptr = ctx.logical_device.device.mapMemory(self.buffer_memory.?, 0, self.layout.size * data.len, .{}) catch {
            log.fatal("Failed to map memory for vertex buffer", .{});
            std.process.exit(1);
        };
        @memcpy(@as([*]T, @alignCast(@ptrCast(map_ptr.?))), data);
        ctx.logical_device.device.unmapMemory(self.buffer_memory.?);
    }

    pub fn get_layout(self: VulkanVertexBuffer) types.BufferLayout {
        return self.layout;
    }

    pub fn deinit(self: VulkanVertexBuffer, ctx: *const context.VulkanContext) void {
        ctx.logical_device.device.deviceWaitIdle() catch {};
        ctx.logical_device.device.destroyBuffer(self.vk_buffer, null);
        ctx.logical_device.device.freeMemory(self.buffer_memory.?, null);
    }
};
