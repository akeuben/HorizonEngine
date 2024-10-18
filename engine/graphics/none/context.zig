const log = @import("../../utils/log.zig");
const Window = @import("../../platform/window.zig").Window;

pub const NoneContext = struct {
    pub fn init(_: NoneContext, _: Window) void {}

    pub fn clear(_: NoneContext) void {}
};
