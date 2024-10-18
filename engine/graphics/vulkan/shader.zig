pub const VulkanVertexShader = struct {
    pub fn init() VulkanVertexShader {
        return .{};
    }
    pub fn deinit(_: VulkanVertexShader) void {}
};

pub const VulkanFragmentShader = struct {
    pub fn init() VulkanFragmentShader {
        return .{};
    }
    pub fn deinit(_: VulkanFragmentShader) void {}
};

pub const VulkanPipeline = struct {
    pub fn init() VulkanPipeline {
        return .{};
    }
    pub fn deinit(_: VulkanPipeline) void {}

    pub fn bind(_: VulkanPipeline) void {}
};
