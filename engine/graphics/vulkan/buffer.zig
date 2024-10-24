const types = @import("../type.zig");

pub const VulkanVertexBuffer = struct {
    pub fn init() VulkanVertexBuffer {
        return .{};
    }

    pub fn bind(_: VulkanVertexBuffer) void {}

    pub fn set_data(_: VulkanVertexBuffer, comptime T: anytype, _: []const T) void {}

    pub fn unbind(_: VulkanVertexBuffer) void {}

    pub fn get_layout(_: VulkanVertexBuffer) types.BufferLayout {
        return undefined;
    }
};
