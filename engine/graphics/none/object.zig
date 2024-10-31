const NoneContext = @import("context.zig").NoneContext;
const NoneVertexBuffer = @import("buffer.zig").NoneVertexBuffer;
const NonePipeline = @import("shader.zig").NonePipeline;

pub const NoneRenderObject = struct {
    pub fn init(_: *const NoneContext, _: *const NoneVertexBuffer, _: *const NonePipeline) NoneRenderObject {
        return .{};
    }
};
