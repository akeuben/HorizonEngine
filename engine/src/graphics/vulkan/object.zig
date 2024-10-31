const VulkanContext = @import("context.zig").VulkanContext;
const VulkanVertexBuffer = @import("buffer.zig").VulkanVertexBuffer;
const VulkanPipeline = @import("shader.zig").VulkanPipeline;
const types = @import("../type.zig");
const vk = @import("vulkan");

pub const VulkanRenderObject = struct {
    buffer: vk.Buffer,
    pipeline: vk.Pipeline,
    layout: types.BufferLayout,

    pub fn init(_: *const VulkanContext, buffer: *const VulkanVertexBuffer, pipeline: *const VulkanPipeline) VulkanRenderObject {
        return .{
            .buffer = buffer.vk_buffer.?.asVulkanBuffer(),
            .pipeline = pipeline.pipeline,
            .layout = buffer.layout,
        };
    }
};
