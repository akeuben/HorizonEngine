const std = @import("std");
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
});
const log = @import("../../utils/log.zig");
const Context = @import("../../graphics/context.zig").Context;
const VulkanExtension = @import("../../graphics/vulkan/extension.zig").VulkanExtension;
const vk = @import("vulkan");
const VulkanContext = @import("../../graphics/vulkan/context.zig").VulkanContext;
const platform = @import("platform");

fn error_callback(error_code: c_int, message: [*c]const u8) callconv(.C) void {
    log.debug("glfw - {}: {s}\n", .{ error_code, message });
}

pub extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
pub extern fn glfwGetPhysicalDevicePresentationSupport(instance: vk.Instance, pdev: vk.PhysicalDevice, queuefamily: u32) c_int;
pub extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *glfw.GLFWwindow, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;

pub const DesktopWindow = struct {
    window: ?*glfw.GLFWwindow,

    pub fn init() void {
        _ = glfw.glfwSetErrorCallback(error_callback);
        if (glfw.glfwInit() != glfw.GLFW_TRUE) {
            log.fatal("Failed to initialize GLFW", .{});
        }
    }

    pub fn set_size_screenspace(self: DesktopWindow, width: i32, height: i32) void {
        glfw.glfwSetWindowSize(self.window, width, height);
    }

    pub fn get_size_pixels(self: DesktopWindow) @Vector(2, i32) {
        var size: @Vector(2, i32) = @splat(0);
        glfw.glfwGetFramebufferSize(self.window, &size[0], &size[1]);
        return size;
    }

    pub fn create_window(context: *const Context) DesktopWindow {
        if (context.* == .VULKAN) {
            glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
            glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, glfw.GLFW_FALSE);
        }
        return DesktopWindow{
            .window = glfw.glfwCreateWindow(480, 320, "Engine", null, null),
        };
    }

    pub fn deinit() void {
        glfw.glfwTerminate();
    }

    pub fn update(_: DesktopWindow) void {
        glfw.glfwPollEvents();
    }

    pub fn set_current_context(self: DesktopWindow, context: Context) void {
        switch (context) {
            .OPEN_GL => glfw.glfwMakeContextCurrent(self.window),
            .VULKAN => {},
            .NONE => {},
        }
    }

    pub fn swap(self: DesktopWindow, context: Context) void {
        switch (context) {
            .OPEN_GL => glfw.glfwSwapBuffers(self.window),
            .VULKAN => {},
            .NONE => {},
        }
    }

    pub fn should_close(self: DesktopWindow) bool {
        return glfw.glfwWindowShouldClose(self.window) == glfw.GLFW_TRUE;
    }

    pub fn get_gl_loader(_: DesktopWindow, gl_extension: []const u8) ?*anyopaque {
        return @ptrCast(@constCast(glfw.glfwGetProcAddress(gl_extension.ptr)));
    }

    pub fn get_proc_addr_fn(_: DesktopWindow) *const anyopaque {
        return glfwGetInstanceProcAddress;
    }

    pub fn get_vk_exts(_: DesktopWindow) []VulkanExtension {
        var count: u32 = 0;
        const glfwExtensions = glfw.glfwGetRequiredInstanceExtensions(&count);
        var extensions = std.heap.page_allocator.alloc(VulkanExtension, count) catch unreachable;
        for (0..count) |i| {
            extensions[i] = VulkanExtension{
                .name = glfwExtensions[i],
                .required = true,
            };
        }
        return extensions;
    }

    pub fn create_vk_surface(self: DesktopWindow, ctx: *const VulkanContext) vk.SurfaceKHR {
        var surface: vk.SurfaceKHR = undefined;
        if (glfwCreateWindowSurface(ctx.instance.instance.handle, self.window.?, null, &surface) != .success) {
            log.fatal("Failed to create window surface", .{});
        }
        return surface;
    }
};
