const NoneContext = @import("context.zig").NoneContext;
const NoneVertexBuffer = @import("buffer.zig").NoneVertexBuffer;
const NonePipeline = @import("shader.zig").NonePipeline;
const NoneRenderTarget = @import("target.zig").NoneRenderTarget;

pub const NoneVertexRenderObject = struct {
    pub fn init(_: *const NoneContext, _: *const NonePipeline, _: *const NoneVertexBuffer) NoneVertexRenderObject {
        return .{};
    }

    pub fn draw(_: NoneVertexRenderObject, _: *const NoneContext, _: *const NoneRenderTarget) void {}
};
