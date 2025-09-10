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
const VulkanSwapchain = @import("../../graphics/vulkan/swapchain.zig");
const platform = @import("platform");
const Window = @import("../window.zig");
const event = @import("../../event/event.zig");

fn error_callback(error_code: c_int, message: [*c]const u8) callconv(.C) void {
    log.debug("glfw - {}: {s}\n", .{ error_code, message });
}

pub extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
pub extern fn glfwGetPhysicalDevicePresentationSupport(instance: vk.Instance, pdev: vk.PhysicalDevice, queuefamily: u32) c_int;
pub extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *glfw.GLFWwindow, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;

fn resize_callback(glfw_window: ?*glfw.GLFWwindow, width: i32, height: i32) callconv(.C) void {
    const window: ?*DesktopWindow = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(glfw_window)));
    _ = window.?.event_node.handle_event_at_root(event.window.WindowResizeEvent, &.{
        .width = width,
        .height = height,
    });
    log.debug("was resized", .{});
}

pub const DesktopWindow = struct {
    window: ?*glfw.GLFWwindow,
    context: *Context,
    event_node: event.EventNode,

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

    pub fn create_window(context: *Context, allocator: std.mem.Allocator) *DesktopWindow {
        if (context.* == .VULKAN) {
            glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
        }
        var window = allocator.create(DesktopWindow) catch unreachable;
        window.window = glfw.glfwCreateWindow(480, 320, "Engine", null, null);
        window.context = context;
        window.event_node = event.EventNode.init(allocator, window, &.{});
        glfw.glfwSetWindowUserPointer(window.window, window);
        _ = glfw.glfwSetFramebufferSizeCallback(window.window, resize_callback);
        glfw.glfwSwapInterval(0);
        return window;
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

    pub fn get_event_node(self: *DesktopWindow) *event.EventNode {
        return &self.event_node;
    }

    pub fn start_frame(self: DesktopWindow) void {
        switch (self.context.*) {
            .OPEN_GL => {},
            .VULKAN => {
                while (true) {
                    if (self.context.VULKAN.swapchain.acquire_image()) {
                        break;
                    } else |err| switch (err) {
                        VulkanSwapchain.AcquireImageError.OutOfDateSwapchain => {
                            // Recreate the swapchain
                            self.context.VULKAN.swapchain.resize(self.get_size_pixels());
                        },
                        else => {
                            log.fatal("Failed to acquire swapchain image.", .{});
                        },
                    }
                }
            },
            .NONE => {},
        }
    }

    pub fn swap(self: *DesktopWindow, ctx: *const Context) void {
        switch (ctx.*) {
            .OPEN_GL => glfw.glfwSwapBuffers(self.window),
            .VULKAN => {
                ctx.VULKAN.swapchain.swap(&Window.Window{ .desktop = self });
            },
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
        if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
            log.fatal("Tried to initialize vulkan, but vulkan could not be found!", .{});
            std.process.exit(1);
        }
        return glfwGetInstanceProcAddress;
    }

    pub fn get_vk_exts(_: DesktopWindow, allocator: std.mem.Allocator) []VulkanExtension {
        if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
            log.fatal("Tried to initialize vulkan, but vulkan could not be found!", .{});
            std.process.exit(1);
        }
        var count: u32 = 0;
        const glfwExtensions = glfw.glfwGetRequiredInstanceExtensions(&count);
        var extensions = allocator.alloc(VulkanExtension, count) catch unreachable;
        for (0..count) |i| {
            extensions[i] = VulkanExtension{
                .name = glfwExtensions[i],
                .required = true,
            };
        }
        return extensions;
    }

    pub fn create_vk_surface(self: DesktopWindow, ctx: *const VulkanContext) vk.SurfaceKHR {
        if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
            log.fatal("Tried to initialize vulkan, but vulkan could not be found!", .{});
            std.process.exit(1);
        }
        var surface: vk.SurfaceKHR = undefined;
        if (glfwCreateWindowSurface(ctx.instance.instance.handle, self.window.?, null, &surface) != .success) {
            log.fatal("Failed to create window surface", .{});
        }
        return surface;
    }
};
