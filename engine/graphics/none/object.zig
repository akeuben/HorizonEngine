const buffer = @import("buffer.zig");
const shader = @import("shader.zig");

pub const NoneRenderObject = struct {
    vertex_buffer: *const buffer.NoneVertexBuffer,
    pipeline: *const shader.NonePipeline,

    pub fn init(vertex_buffer: *const buffer.NoneVertexBuffer, pipeline: *const shader.NonePipeline) NoneRenderObject {
        return .{
            .vertex_buffer = vertex_buffer,
            .pipeline = pipeline,
        };
    }

    pub fn bind(_: NoneRenderObject) void {}
    pub fn render(_: NoneRenderObject) void {}
    pub fn unbind(_: NoneRenderObject) void {}
};
