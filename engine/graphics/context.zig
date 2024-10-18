const opengl = @import("opengl/context.zig");
const vulkan = @import("vulkan/context.zig");
const OpenGLContext = @import("opengl/context.zig").OpenGLContext;
const VulkanContext = @import("vulkan/context.zig").VulkanContext;
const NoneContext = @import("none/context.zig").NoneContext;
const Window = @import("../platform/window.zig").Window;

pub const API = enum { OPEN_GL, VULKAN, NONE };

pub const Context = union(API) {
    OPEN_GL: OpenGLContext,
    VULKAN: VulkanContext,
    NONE: NoneContext,

    pub fn init(self: Context, window: Window) void {
        switch (self) {
            inline else => |case| case.init(window),
        }
    }

    pub fn clear(self: Context) void {
        switch (self) {
            inline else => |case| case.clear(),
        }
    }
};

pub fn create_context(context_api: API) Context {
    return switch (context_api) {
        .OPEN_GL => Context{ .OPEN_GL = .{} },
        .VULKAN => Context{ .VULKAN = .{} },
        .NONE => Context{ .NONE = .{} },
    };
}
