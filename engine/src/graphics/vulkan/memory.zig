const context = @import("context.zig");
const allocator = @import("allocator.zig");
const vk = @import("vulkan");
const log = @import("../../utils/log.zig");

const oneshot_init_err = error {
    AllocateError,
    StartError,
};

inline fn has_stencil_component(format: vk.Format) bool {
    return format == .d32_sfloat_s8_uint or format == .d24_unorm_s8_uint;
}

pub fn init_oneshot_command(ctx: *const context.VulkanContext) oneshot_init_err!vk.CommandBuffer {
    const alloc_info = vk.CommandBufferAllocateInfo{
        .level = .primary,
        .command_pool = ctx.command_pool,
        .command_buffer_count = 1,
    };

    var command_buffer: vk.CommandBuffer = undefined;
    ctx.logical_device.device.allocateCommandBuffers(&alloc_info, @ptrCast(&command_buffer)) catch {
        log.err("Failed to create command buffer for memory copy", .{});
        return oneshot_init_err.AllocateError;
    };

    ctx.logical_device.device.beginCommandBuffer(command_buffer, &.{
        .flags = .{ .one_time_submit_bit = true },
    }) catch {
        log.err("Failed to start command buffer for memory transfer operation", .{});
        ctx.logical_device.device.queueWaitIdle(ctx.graphics_queue) catch {};
        //ctx.logical_device.device.freeCommandBuffers(ctx.command_pool, 1, @ptrCast(&command_buffer));
        return oneshot_init_err.StartError;
    };

    return command_buffer;
}

pub fn deinit_oneshot_command(command_buffer: vk.CommandBuffer, ctx: *const context.VulkanContext) void {
    defer ctx.logical_device.device.queueWaitIdle(ctx.graphics_queue) catch {};
    //defer ctx.logical_device.device.freeCommandBuffers(ctx.command_pool, 1, @ptrCast(&command_buffer));

    ctx.logical_device.device.endCommandBuffer(command_buffer) catch {
        log.err("Failed to record command buffer for memory transfer operation", .{});
        return;
    };

    const submit_info = vk.SubmitInfo{
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast(&command_buffer),
    };

    ctx.logical_device.device.queueSubmit(ctx.graphics_queue, 1, @ptrCast(&submit_info), .null_handle) catch {
        log.err("Failed to submit command buffer for memory transfer operation", .{});
    };

}

pub fn copy_buffer(ctx: *const context.VulkanContext, src: vk.Buffer, dst: vk.Buffer, size: vk.DeviceSize) void {
    const command_buffer = init_oneshot_command(ctx) catch {
        return;
    };
    defer deinit_oneshot_command(command_buffer, ctx);

    const copy_region = vk.BufferCopy{
        .src_offset = 0,
        .dst_offset = 0,
        .size = size,
    };

    ctx.logical_device.device.cmdCopyBuffer(command_buffer, src, dst, 1, @ptrCast(&copy_region));
}

pub fn transition_image_layout(ctx: *const context.VulkanContext, image: *const allocator.AllocatedVulkanImage, format: vk.Format, old_layout: vk.ImageLayout, new_layout: vk.ImageLayout) void {
    const command_buffer = init_oneshot_command(ctx) catch {
        return;
    };
    defer deinit_oneshot_command(command_buffer, ctx);

    var barrier = vk.ImageMemoryBarrier{
        .old_layout = old_layout,
        .new_layout = new_layout,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = image.asVulkanImage(),
        .subresource_range = .{
            .aspect_mask = .{ 
                .color_bit = new_layout != .depth_stencil_attachment_optimal, 
                .depth_bit = new_layout == .depth_stencil_attachment_optimal,
                .stencil_bit = new_layout == .depth_stencil_attachment_optimal and has_stencil_component(format),
            },
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1,
        },
        .src_access_mask = .{},
        .dst_access_mask = .{},
    };

    var source_stage: vk.PipelineStageFlags = undefined;
    var destination_stage: vk.PipelineStageFlags = undefined;

    if(old_layout == .undefined and new_layout == .transfer_dst_optimal) {
        barrier.src_access_mask = .{};
        barrier.dst_access_mask = .{ .transfer_write_bit = true };
        
        source_stage = .{ .top_of_pipe_bit = true };
        destination_stage = .{ .transfer_bit = true };
    } else if(old_layout == .transfer_dst_optimal and new_layout == .shader_read_only_optimal) {
        barrier.src_access_mask = .{ .transfer_write_bit = true };
        barrier.dst_access_mask = .{ .shader_read_bit = true };
        
        source_stage = .{ .transfer_bit = true };
        destination_stage = .{ .fragment_shader_bit = true };
    } else if (old_layout == .undefined and new_layout == .depth_stencil_attachment_optimal) {
        barrier.src_access_mask = .{};
        barrier.dst_access_mask = .{
            .depth_stencil_attachment_read_bit = true,
            .depth_stencil_attachment_write_bit = true,
        };

        source_stage = .{ .top_of_pipe_bit = true };
        destination_stage = .{ .early_fragment_tests_bit = true };
    } else {
        log.err("Invalid vulkan image transition", .{});
        return;
    }

    ctx.logical_device.device.cmdPipelineBarrier(command_buffer, source_stage, destination_stage, .{}, 0, null, 0, null, 1, @ptrCast(&barrier));
}

pub fn copy_buffer_to_image(ctx: *const context.VulkanContext, src: allocator.AllocatedVulkanBuffer, dst: allocator.AllocatedVulkanImage, extent: vk.Extent3D) void {
    const command_buffer = init_oneshot_command(ctx) catch {
        return;
    };
    defer deinit_oneshot_command(command_buffer, ctx);

    const region = vk.BufferImageCopy{
        .buffer_offset = 0,
        .buffer_row_length = 0,
        .buffer_image_height = 0,
        .image_subresource = .{
            .aspect_mask = .{ .color_bit = true },
            .mip_level = 0,
            .base_array_layer = 0,
            .layer_count = 1,
        },
        .image_extent = extent,
        .image_offset = .{ .x = 0, .y = 0, .z = 0 },
    };

    ctx.logical_device.device.cmdCopyBufferToImage(command_buffer, src.asVulkanBuffer(), dst.asVulkanImage(), .transfer_dst_optimal, 1, @ptrCast(&region));
}
