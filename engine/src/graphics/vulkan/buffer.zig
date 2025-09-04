const std = @import("std");
const types = @import("../type.zig");
const vk = @import("vulkan");
const log = @import("../../utils/log.zig");
const context = @import("context.zig");
const allocator = @import("allocator.zig");
const MAX_FRAMES_IN_FLIGHT = @import("./swapchain.zig").MAX_FRAMES_IN_FLIGHT;

fn copy_buffer(ctx: *const context.VulkanContext, src: vk.Buffer, dst: vk.Buffer, size: vk.DeviceSize) void {
    const alloc_info = vk.CommandBufferAllocateInfo{
        .level = .primary,
        .command_pool = ctx.command_pool,
        .command_buffer_count = 1,
    };

    var command_buffer: vk.CommandBuffer = undefined;
    ctx.logical_device.device.allocateCommandBuffers(&alloc_info, @ptrCast(&command_buffer)) catch {
        log.fatal("Failed to create command buffer for memory copy", .{});
    };

    ctx.logical_device.device.beginCommandBuffer(command_buffer, &.{
        .flags = .{ .one_time_submit_bit = true },
    }) catch {
        log.fatal("Failed to start command buffer for memory transfer operation", .{});
    };

    const copy_region = vk.BufferCopy{
        .src_offset = 0,
        .dst_offset = 0,
        .size = size,
    };
    ctx.logical_device.device.cmdCopyBuffer(command_buffer, src, dst, 1, @ptrCast(&copy_region));
    ctx.logical_device.device.endCommandBuffer(command_buffer) catch {
        log.fatal("Failed to record command buffer for memory transfer operation", .{});
    };

    const submit_info = vk.SubmitInfo{
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast(&command_buffer),
    };

    ctx.logical_device.device.queueSubmit(ctx.graphics_queue, 1, @ptrCast(&submit_info), .null_handle) catch {
        log.fatal("Failed to submit command buffer for memory transfer operation", .{});
    };

    ctx.logical_device.device.queueWaitIdle(ctx.graphics_queue) catch {};

    ctx.logical_device.device.freeCommandBuffers(ctx.command_pool, 1, @ptrCast(&command_buffer));
}

pub const VulkanVertexBuffer = struct {
    layout: types.BufferLayout,
    ctx: *const context.VulkanContext,
    vk_buffer: ?allocator.AllocatedVulkanBuffer,

    pub fn init(ctx: *const context.VulkanContext, comptime T: anytype, data: []const T) VulkanVertexBuffer {
        var buffer: VulkanVertexBuffer = undefined;
        buffer.ctx = ctx;
        buffer.vk_buffer = null;

        buffer.set_data(T, data);

        return buffer;
    }

    pub fn set_data(self: *VulkanVertexBuffer, comptime T: anytype, data: []const T) void {
        if (self.vk_buffer != null) {
            self.deinit();
        }
        self.layout = types.generate_layout(T, data, self.ctx.allocator) catch {
            log.fatal("Failed to generate layout of vertex buffer", .{});
            unreachable;
        };
        const buffer_size: vk.DeviceSize = self.layout.size * data.len;

        const staging_buffer = self.ctx.vk_allocator.create_buffer(buffer_size, .{ .transfer_src_bit = true }, .{ .host_visible_bit = true, .host_coherent_bit = true });
        defer self.ctx.vk_allocator.destroy_buffer(staging_buffer);

        const map_ptr = self.ctx.vk_allocator.map_buffer(T, staging_buffer);
        @memcpy(@as([*]T, @alignCast(@ptrCast(map_ptr))), data);
        self.ctx.vk_allocator.unmap_buffer(staging_buffer);

        self.vk_buffer = self.ctx.vk_allocator.create_buffer(buffer_size, .{ .transfer_dst_bit = true, .vertex_buffer_bit = true }, .{ .device_local_bit = true });

        copy_buffer(self.ctx, staging_buffer.asVulkanBuffer(), self.vk_buffer.?.asVulkanBuffer(), buffer_size);

        self.ctx.logical_device.device.queueWaitIdle(self.ctx.graphics_queue) catch {};
    }

    pub fn get_layout(self: VulkanVertexBuffer) types.BufferLayout {
        return self.layout;
    }

    pub fn deinit(self: *VulkanVertexBuffer) void {
        log.debug("Deinit vertex buffer", .{});
        self.layout.deinit();
        self.ctx.logical_device.device.deviceWaitIdle() catch {};
        self.ctx.vk_allocator.destroy_buffer(self.vk_buffer.?);
    }
};

pub const VulkanIndexBuffer = struct {
    vk_buffer: ?allocator.AllocatedVulkanBuffer,
    ctx: *const context.VulkanContext,
    count: u32,

    pub fn init(ctx: *const context.VulkanContext, data: []const u32) VulkanIndexBuffer {
        var buffer = VulkanIndexBuffer{
            .vk_buffer = undefined,
            .ctx = ctx,
            .count = @intCast(data.len),
        };

        buffer.set_data(ctx, data);

        return buffer;
    }

    pub fn set_data(self: *VulkanIndexBuffer, ctx: *const context.VulkanContext, data: []const u32) void {
        if (self.vk_buffer != null) {
            self.deinit();
        }
        self.count = @intCast(data.len);
        const buffer_size: vk.DeviceSize = @sizeOf(u32) * data.len;

        const staging_buffer = ctx.vk_allocator.create_buffer(buffer_size, .{ .transfer_src_bit = true }, .{ .host_visible_bit = true, .host_coherent_bit = true });
        defer ctx.vk_allocator.destroy_buffer(staging_buffer);

        const map_ptr = ctx.vk_allocator.map_buffer(u32, staging_buffer);
        @memcpy(@as([*]u32, @alignCast(@ptrCast(map_ptr))), data);
        ctx.vk_allocator.unmap_buffer(staging_buffer);

        self.vk_buffer = ctx.vk_allocator.create_buffer(buffer_size, .{ .transfer_dst_bit = true, .index_buffer_bit = true }, .{ .device_local_bit = true });

        copy_buffer(ctx, staging_buffer.asVulkanBuffer(), self.vk_buffer.?.asVulkanBuffer(), buffer_size);

        ctx.logical_device.device.queueWaitIdle(ctx.graphics_queue) catch {};
    }

    pub fn get_layout(self: VulkanIndexBuffer) types.BufferLayout {
        return self.layout;
    }

    pub fn deinit(self: VulkanIndexBuffer) void {
        log.debug("Deinit index buffer", .{});
        self.ctx.logical_device.device.deviceWaitIdle() catch {};
        self.ctx.vk_allocator.destroy_buffer(self.vk_buffer.?);
    }
};

pub const VulkanUniformBuffer = struct {
    vk_buffer: [MAX_FRAMES_IN_FLIGHT] allocator.AllocatedVulkanBuffer,
    vk_memory: [MAX_FRAMES_IN_FLIGHT] *anyopaque,
    ctx: *const context.VulkanContext,
    size: usize,

    pub fn init(ctx: *const context.VulkanContext, comptime T: anytype, data: T) VulkanUniformBuffer {
        var buffer = VulkanUniformBuffer{
            .vk_buffer = undefined,
            .vk_memory = undefined,
            .ctx = ctx,
            .size = @sizeOf(T),
        };

        for(0..MAX_FRAMES_IN_FLIGHT) |i| {
            const buffer_size: vk.DeviceSize = @sizeOf(T);
            buffer.vk_buffer[i] = ctx.vk_allocator.create_buffer(buffer_size, .{ .uniform_buffer_bit = true}, .{ .host_visible_bit = true, .host_coherent_bit = true });
            buffer.vk_memory[i] = ctx.vk_allocator.map_buffer(T, buffer.vk_buffer[i]);
            const ptr: *T = @alignCast(@ptrCast(buffer.vk_memory[i]));
            ptr.* = data;
        }

        set_data(&buffer, ctx, T, data);

        return buffer;
    }

    pub fn set_data(self: *VulkanUniformBuffer, ctx: *const context.VulkanContext, comptime T: anytype, data: T) void {
        const ptr: *T = @alignCast(@ptrCast(self.vk_memory[ctx.swapchain.current_frame]));
        ptr.* = data;
    }

    pub fn deinit(self: VulkanUniformBuffer) void {
        log.debug("Deinit uniform buffer", .{});
        for(0..MAX_FRAMES_IN_FLIGHT) |i| {
            self.ctx.vk_allocator.unmap_buffer(self.vk_buffer[i]);
            self.ctx.vk_allocator.destroy_buffer(self.vk_buffer[i]);
        }
    }
};
