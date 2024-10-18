const opengl = @import("opengl/context.zig");
const vulkan = @import("vulkan/context.zig");
const none = @import("none/context.zig");
const Window = @import("../platform/window.zig").Window;

pub const API = enum { OPEN_GL, VULKAN, NONE };

pub const Context = union(API) {
    OPEN_GL: opengl.OpenGLContext,
    VULKAN: vulkan.VulkanContext,
    NONE: none.NoneContext,

    pub fn init_open_gl(window: *const Window) Context {
        return Context{
            .OPEN_GL = opengl.OpenGLContext.init(window),
        };
    }

    pub fn init_vulkan() Context {
        return Context{
            .VULKAN = vulkan.VulkanContext.init(),
        };
    }

    pub fn init_none() Context {
        return Context{
            .NONE = none.NoneContext.init(),
        };
    }

    pub fn clear(self: Context) void {
        switch (self) {
            inline else => |case| case.clear(),
        }
    }
};
