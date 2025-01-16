const std = @import("std");
const context = @import("context.zig");
const NonePipeline = @import("shader.zig").NonePipeline;
const NoneVertexBuffer = @import("buffer.zig").NoneVertexBuffer;
const RenderObject = @import("../object.zig").RenderObject;
const gl = @import("gl");

pub const NoneRenderTarget = struct {
    pub fn init(_: *const context.NoneContext, allocator: std.mem.Allocator) *NoneRenderTarget {
        return allocator.alloc(NoneRenderTarget);
    }

    pub fn start(_: *const NoneRenderTarget) void {}

    pub fn render(_: *const NoneRenderTarget, _: *const RenderObject) void {}

    pub fn end(_: *const NoneRenderTarget) void {}
    pub fn submit(_: *const NoneRenderTarget) void {}

    pub fn deinit(_: NoneRenderTarget) void {}
};
