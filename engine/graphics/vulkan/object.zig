const buffer = @import("buffer.zig");
const shader = @import("shader.zig");

pub const VulkanRenderObject = struct {
    vertex_buffer: *const buffer.VulkanVertexBuffer,
    pipeline: *const shader.VulkanPipeline,

    pub fn init(vertex_buffer: *const buffer.VulkanVertexBuffer, pipeline: *const shader.VulkanPipeline) VulkanRenderObject {
        return .{
            .vertex_buffer = vertex_buffer,
            .pipeline = pipeline,
        };
    }

    pub fn bind(_: VulkanRenderObject) void {}
    pub fn render(_: VulkanRenderObject) void {}
    pub fn unbind(_: VulkanRenderObject) void {}
};
