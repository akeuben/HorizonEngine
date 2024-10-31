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

    pub fn init(ctx: *const context.Context, vertex_buffer: *const buffer.VertexBuffer, pipeline: *const shader.Pipeline) RenderObject {
        return switch (ctx.*) {
            .OPEN_GL => RenderObject{
                .OPEN_GL = opengl.OpenGLRenderObject.init(&ctx.OPEN_GL, &vertex_buffer.OPEN_GL, &pipeline.OPEN_GL),
            },
            .VULKAN => RenderObject{
                .VULKAN = vulkan.VulkanRenderObject.init(&ctx.VULKAN, &vertex_buffer.VULKAN, &pipeline.VULKAN),
            },
            .NONE => RenderObject{
                .NONE = none.NoneRenderObject.init(&ctx.NONE, &vertex_buffer.NONE, &pipeline.NONE),
            },
        };
    }
};
