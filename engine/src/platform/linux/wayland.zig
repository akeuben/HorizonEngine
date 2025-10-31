const std = @import("std");
const log = @import("../../utils/log.zig");
const wayland = @import("wayland");
const Context = @import("../../graphics/context.zig").Context;
const event = @import("../../event/event.zig");
const VulkanSwapchain = @import("../../graphics/vulkan/swapchain.zig");
const VulkanExtension = @import("../../graphics/vulkan/extension.zig").VulkanExtension;
const vk = @import("vulkan");
const VulkanContext = @import("../../graphics/vulkan/context.zig").VulkanContext;
const Window = @import("../window.zig").Window;

const wl = wayland.client.wl;
const xdg = wayland.client.xdg;

var display: *wl.Display = undefined;

pub const WaylandWindow = struct {
    context: *const Context,
    node: event.EventNode,
    width: i32,
    height: i32,
    pending_exit: bool,

    pub fn init() void {
        display = wl.Display.connect(null) catch {
            log.fatal("Failed to connect to wayland display!", .{});
        };

        wl.Display.disconnect(display);
    }

    pub fn set_size_screenspace(self: WaylandWindow, width: i32, height: i32) void {
        _ = self;
        _ = width;
        _ = height;
    }

    pub fn get_size_pixels(self: WaylandWindow) @Vector(2, i32) {
        _ = self;
        log.fatal("Not Implemented", .{});
    }
    
    pub fn create_window(context: *Context, allocator: std.mem.Allocator) *WaylandWindow {
        const window = allocator.create(WaylandWindow) catch unreachable;
        window.context = context;
        window.width = 800;
        window.height = 600;
        window.pending_exit = false;
        window.node = event.EventNode.init(allocator, null, &.{});

        return window;
    }

    pub fn deinit() void {
    
    }

    pub fn update(window: *WaylandWindow) void {
        _ = window;
    }

    pub fn set_current_context(self: WaylandWindow, context: Context) void {
        _ = self;
        switch(context) {
            else => {},
        }
    }

    pub fn get_event_node(self: *WaylandWindow) *event.EventNode {
        return &self.node;
    }

    pub fn start_frame(self: WaylandWindow) void {
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

    pub fn swap(self: *WaylandWindow, ctx: *const Context) void {
        switch(ctx.*) {
            .OPEN_GL => {
                log.fatal("Swapping not implemented for OpenGL under wayland", .{});
            },
            .VULKAN => {
                ctx.VULKAN.swapchain.swap(&Window{ .linux = self });
            },
            else => {},
        }
    }

    pub fn should_close(self: WaylandWindow) bool {
        return self.pending_exit;
    }

    pub fn get_gl_loader(self: *const WaylandWindow, gl_extension: []const u8) ?*anyopaque {
        _ = self;
        _ = gl_extension;
        log.fatal("GL Loader not implemented for wayland", .{});
    }

    pub fn get_proc_addr_fn(_: WaylandWindow) *const anyopaque {
        // Load the Vulkan loader
        var lib = std.DynLib.open("libvulkan.so.1") catch {
            log.fatal("Failed to open libvulkan.so.1", .{});
        };

        const vkGetInstanceProcAddr = lib.lookup(*const anyopaque, "vkGetInstanceProcAddr") orelse {
            log.fatal("Failed to find vkGetInstanceProcAddr", .{});
        };
        return vkGetInstanceProcAddr;
    }

    pub fn get_vk_exts(_: WaylandWindow, allocator: std.mem.Allocator) []VulkanExtension {
        var extensions = allocator.alloc(VulkanExtension, 2) catch unreachable;
        extensions[0] = VulkanExtension{
            .name = "VK_KHR_surface",
            .required = true,
        };
        extensions[1] = VulkanExtension{
            .name = "VK_KHR_wayland_surface",
            .required = true,
        };
        return extensions;
    }

    pub fn create_vk_surface(self: WaylandWindow, ctx: *const VulkanContext) vk.SurfaceKHR {
        _ = self;
        _ = ctx;
        log.fatal("create_vk_surface not implemented for wayland", .{});
    }
};
