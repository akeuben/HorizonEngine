const log = @import("../../utils/log.zig");
const Window = @import("../../platform/window.zig").Window;
const NoneVertexBuffer = @import("buffer.zig").NoneVertexBuffer;
const NonePipeline = @import("shader.zig").NonePipeline;

pub const NoneContext = struct {
    pub fn init() void {}

    pub fn deinit(_: NoneContext) void {}

    pub fn load(_: *NoneContext, _: *const Window) void {}
    pub fn clear(_: NoneContext) void {}
    pub fn render(_: NoneContext, _: NonePipeline, _: NoneVertexBuffer) void {}
    pub fn flush(_: NoneContext) void {}
};
