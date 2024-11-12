const VulkanContext = @import("context.zig").VulkanContext;
const VulkanVertexBuffer = @import("buffer.zig").VulkanVertexBuffer;
const VulkanIndexBuffer = @import("buffer.zig").VulkanIndexBuffer;
const VulkanPipeline = @import("shader.zig").VulkanPipeline;
const VulkanRenderTarget = @import("target.zig").VulkanRenderTarget;
const types = @import("../type.zig");
const vk = @import("vulkan");

const ObjectType = enum {
    INDEXED,
    LIST,
};

pub const VulkanVertexRenderObject = struct {
    pipeline: vk.Pipeline,
    vertex_buffer: vk.Buffer,
    layout: types.BufferLayout,

    pub fn init(_: *const VulkanContext, pipeline: *const VulkanPipeline, vertex_buffer: *const VulkanVertexBuffer) VulkanVertexRenderObject {
        return .{
            .vertex_buffer = vertex_buffer.vk_buffer.?.asVulkanBuffer(),
            .pipeline = pipeline.pipeline,
            .layout = vertex_buffer.layout,
        };
    }

    pub fn draw(self: *const VulkanVertexRenderObject, ctx: *const VulkanContext, target: *const VulkanRenderTarget) void {
        ctx.logical_device.device.cmdBindPipeline(target.get_current_commandbuffer(), .graphics, self.pipeline);

        const buffers: []const vk.Buffer = &.{self.vertex_buffer};
        const offsets: []const vk.DeviceSize = &.{0};

        ctx.logical_device.device.cmdBindVertexBuffers(target.get_current_commandbuffer(), 0, 1, @ptrCast(buffers.ptr), @ptrCast(offsets.ptr));

        ctx.logical_device.device.cmdDraw(target.get_current_commandbuffer(), @intCast(self.layout.length), 1, 0, 0);
    }
};

pub const VulkanIndexRenderObject = struct {
    pipeline: vk.Pipeline,
    vertex_buffer: vk.Buffer,
    index_buffer: vk.Buffer,
    layout: types.BufferLayout,
    count: u32,

    pub fn init(_: *const VulkanContext, pipeline: *const VulkanPipeline, vertex_buffer: *const VulkanVertexBuffer, index_buffer: *const VulkanIndexBuffer) VulkanIndexRenderObject {
        return .{
            .vertex_buffer = vertex_buffer.vk_buffer.?.asVulkanBuffer(),
            .index_buffer = index_buffer.vk_buffer.?.asVulkanBuffer(),
            .pipeline = pipeline.pipeline,
            .layout = vertex_buffer.layout,
            .count = index_buffer.count,
        };
    }

    pub fn draw(self: *const VulkanIndexRenderObject, ctx: *const VulkanContext, target: *const VulkanRenderTarget) void {
        ctx.logical_device.device.cmdBindPipeline(target.get_current_commandbuffer(), .graphics, self.pipeline);

        const buffers: []const vk.Buffer = &.{self.vertex_buffer};
        const offsets: []const vk.DeviceSize = &.{0};

        ctx.logical_device.device.cmdBindVertexBuffers(target.get_current_commandbuffer(), 0, 1, @ptrCast(buffers.ptr), @ptrCast(offsets.ptr));

        ctx.logical_device.device.cmdBindIndexBuffer(target.get_current_commandbuffer(), self.index_buffer, 0, .uint32);
        ctx.logical_device.device.cmdDrawIndexed(target.get_current_commandbuffer(), @intCast(self.count), 1, 0, 0, 0);
    }
};
