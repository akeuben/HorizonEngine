const log = @import("../../utils/log.zig");
const Window = @import("../../platform/window.zig").Window;

pub const VulkanContext = struct {
    pub fn init() void {
        log.fatal("Method stub", .{});
    }

    pub fn clear(_: VulkanContext) void {}
};
