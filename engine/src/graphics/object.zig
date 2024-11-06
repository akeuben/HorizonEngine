const context = @import("context.zig");
const opengl = @import("opengl/object.zig");
const vulkan = @import("vulkan/object.zig");
const none = @import("none/object.zig");
const shader = @import("shader.zig");
const buffer = @import("buffer.zig");

pub const RenderObject = union(context.API) {
    OPEN_GL: opengl.OpenGLRenderObject,
    VULKAN: vulkan.VulkanRenderObject,
    NONE: none.NoneRenderObject,

    pub fn init(ctx: *const context.Context, pipeline: *const shader.Pipeline, vertex_buffer: *const buffer.VertexBuffer, index_buffer: ?*const buffer.IndexBuffer) RenderObject {
        return switch (ctx.*) {
            .OPEN_GL => RenderObject{
                .OPEN_GL = opengl.OpenGLRenderObject.init(&ctx.OPEN_GL, &pipeline.OPEN_GL, &vertex_buffer.OPEN_GL, if (index_buffer != null) &index_buffer.?.OPEN_GL else null),
            },
            .VULKAN => RenderObject{
                .VULKAN = vulkan.VulkanRenderObject.init(&ctx.VULKAN, &pipeline.VULKAN, &vertex_buffer.VULKAN, if (index_buffer != null) &index_buffer.?.VULKAN else null),
            },
            .NONE => RenderObject{
                .NONE = none.NoneRenderObject.init(&ctx.NONE, &vertex_buffer.NONE, &pipeline.NONE),
            },
        };
    }
};
