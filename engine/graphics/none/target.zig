const context = @import("context.zig");
const NonePipeline = @import("shader.zig").NonePipeline;
const NoneVertexBuffer = @import("buffer.zig").NoneVertexBuffer;
const gl = @import("gl");

pub const NoneRenderTarget = struct {
    pub fn init(_: *const context.NoneContext) NoneRenderTarget {
        return NoneRenderTarget{};
    }

    pub fn start(_: *const NoneRenderTarget, _: *const context.NoneContext) void {}

    pub fn render(_: *const NoneRenderTarget, _: *const context.NoneContext, _: *const NonePipeline, _: *const NoneVertexBuffer) void {}

    pub fn end(_: *const NoneRenderTarget, _: *const context.NoneContext) void {}
    pub fn submit(_: *const NoneRenderTarget, _: *const context.NoneContext) void {}

    pub fn deinit(_: NoneRenderTarget) void {}
};
