const context = @import("context.zig");
const opengl = @import("opengl/object.zig");
const vulkan = @import("vulkan/object.zig");
const none = @import("none/object.zig");
const log = @import("../utils/log.zig");
const types = @import("type.zig");
const buffer = @import("buffer.zig");
const shader = @import("shader.zig");

pub const RenderObject = union(context.API) {
    OPEN_GL: opengl.OpenGLRenderObject,
    VULKAN: vulkan.VulkanRenderObject,
    NONE: none.NoneRenderObject,

    pub fn init(ctx: *const context.Context, vertex_buffer: *const buffer.VertexBuffer, pipeline: *const shader.Pipeline) RenderObject {
        return switch (ctx.*) {
            .OPEN_GL => RenderObject{
                .OPEN_GL = opengl.OpenGLRenderObject.init(&vertex_buffer.OPEN_GL, &pipeline.OPEN_GL),
            },
            .VULKAN => RenderObject{
                .VULKAN = vulkan.VulkanRenderObject.init(&vertex_buffer.VULKAN, &pipeline.VULKAN),
            },
            .NONE => RenderObject{
                .NONE = none.NoneRenderObject.init(&vertex_buffer.NONE, &pipeline.NONE),
            },
        };
    }

    pub fn bind(self: RenderObject) void {
        switch (self) {
            inline else => |case| case.bind(),
        }
    }

    pub fn render(self: RenderObject) void {
        switch (self) {
            inline else => |case| case.render(),
        }
    }

    pub fn unbind(self: RenderObject) void {
        switch (self) {
            inline else => |case| case.unbind(),
        }
    }
};
