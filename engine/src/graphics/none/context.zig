const log = @import("../../utils/log.zig");
const Window = @import("../../platform/window.zig").Window;
const NoneVertexBuffer = @import("buffer.zig").NoneVertexBuffer;
const NonePipeline = @import("shader.zig").NonePipeline;
const NoneRenderTarget = @import("target.zig").NoneRenderTarget;

pub const NoneContext = struct {
    target: NoneRenderTarget,

    pub fn init() NoneContext {
        return NoneContext{
            .target = .{},
        };
    }

    pub fn deinit(_: NoneContext) void {}

    pub fn get_target(self: *NoneContext) *NoneRenderTarget {
        return &self.target;
    }

    pub fn notify_resized(_: *NoneContext) void {}

    pub fn load(_: *NoneContext, _: *const Window) void {}
};
