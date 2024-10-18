pub const NoneVertexBuffer = struct {
    pub fn init() NoneVertexBuffer {
        return .{};
    }

    pub fn bind(_: NoneVertexBuffer) void {}

    pub fn set_data(_: NoneVertexBuffer, comptime T: anytype, _: []const T) void {}

    pub fn unbind(_: NoneVertexBuffer) void {}
};
