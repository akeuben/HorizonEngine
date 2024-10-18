pub const NoneVertexShader = struct {
    pub fn init() NoneVertexShader {
        return .{};
    }
    pub fn deinit(_: NoneVertexShader) void {}
};

pub const NoneFragmentShader = struct {
    pub fn init() NoneFragmentShader {
        return .{};
    }
    pub fn deinit(_: NoneFragmentShader) void {}
};

pub const NonePipeline = struct {
    pub fn init() NonePipeline {
        return .{};
    }
    pub fn deinit(_: NonePipeline) void {}

    pub fn bind(_: NonePipeline) void {}
};
