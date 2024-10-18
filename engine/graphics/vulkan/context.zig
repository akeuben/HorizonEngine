const log = @import("../../utils/log.zig");
const Window = @import("../../platform/window.zig").Window;

pub const VulkanContext = struct {
    pub fn init(_: VulkanContext, _: Window) void {
        log.fatal("Method stub", .{});
    }

    pub fn clear(_: VulkanContext) void {}
};
