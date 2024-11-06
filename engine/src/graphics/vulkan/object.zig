const VulkanContext = @import("context.zig").VulkanContext;
const VulkanVertexBuffer = @import("buffer.zig").VulkanVertexBuffer;
const VulkanIndexBuffer = @import("buffer.zig").VulkanIndexBuffer;
const VulkanPipeline = @import("shader.zig").VulkanPipeline;
const types = @import("../type.zig");
const vk = @import("vulkan");

const ObjectType = enum {
    INDEXED,
    LIST,
};

pub const VulkanRenderObject = struct {
    vertex_buffer: vk.Buffer,
    index_buffer: ?vk.Buffer,
    pipeline: vk.Pipeline,
    layout: types.BufferLayout,
    count: u32,

    pub fn init(_: *const VulkanContext, pipeline: *const VulkanPipeline, vertex_buffer: *const VulkanVertexBuffer, index_buffer: ?*const VulkanIndexBuffer) VulkanRenderObject {
        return .{
            .vertex_buffer = vertex_buffer.vk_buffer.?.asVulkanBuffer(),
            .index_buffer = if (index_buffer == null) null else index_buffer.?.vk_buffer.?.asVulkanBuffer(),
            .pipeline = pipeline.pipeline,
            .layout = vertex_buffer.layout,
            .count = if (index_buffer == null) 0 else index_buffer.?.count,
        };
    }
};
