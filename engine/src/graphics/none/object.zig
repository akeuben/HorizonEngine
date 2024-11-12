const NoneContext = @import("context.zig").NoneContext;
const NoneVertexBuffer = @import("buffer.zig").NoneVertexBuffer;
const NoneIndexBuffer = @import("buffer.zig").NoneIndexBuffer;
const NonePipeline = @import("shader.zig").NonePipeline;
const NoneRenderTarget = @import("target.zig").NoneRenderTarget;

pub const NoneVertexRenderObject = struct {
    pub fn init(_: *const NoneContext, _: *const NonePipeline, _: *const NoneVertexBuffer) NoneVertexRenderObject {
        return .{};
    }

    pub fn draw(_: NoneVertexRenderObject, _: *const NoneContext, _: *const NoneRenderTarget) void {}
};

pub const NoneIndexRenderObject = struct {
    pub fn init(_: *const NoneContext, _: *const NonePipeline, _: *const NoneVertexBuffer, _: *const NoneIndexBuffer) NoneIndexRenderObject {
        return .{};
    }

    pub fn draw(_: NoneIndexRenderObject, _: *const NoneContext, _: *const NoneRenderTarget) void {}
};
