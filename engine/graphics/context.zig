const opengl = @import("opengl/context.zig");
const vulkan = @import("vulkan/context.zig");
const none = @import("none/context.zig");
const Window = @import("../platform/window.zig").Window;

pub const API = enum { OPEN_GL, VULKAN, NONE };

pub const Context = union(API) {
    OPEN_GL: opengl.OpenGLContext,
    VULKAN: vulkan.VulkanContext,
    NONE: none.NoneContext,

    pub fn init_open_gl() Context {
        return Context{
            .OPEN_GL = opengl.OpenGLContext.init(),
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

    pub fn deinit(self: Context) void {
        switch (self) {
            inline else => |case| case.deinit(),
        }
    }

    pub fn load(self: *Context, window: *const Window) void {
        switch (self.*) {
            .OPEN_GL => opengl.OpenGLContext.load(&self.OPEN_GL, window),
            .VULKAN => vulkan.VulkanContext.load(&self.VULKAN, window),
            .NONE => none.NoneContext.load(&self.NONE, window),
        }
    }

    pub fn clear(self: Context) void {
        switch (self) {
            inline else => |case| case.clear(),
        }
    }
};
