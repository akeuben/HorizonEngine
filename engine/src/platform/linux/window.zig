const std = @import("std");
const log = @import("../../utils/log.zig");
const Context = @import("../../graphics/context.zig").Context;
const VulkanExtension = @import("../../graphics/vulkan/extension.zig").VulkanExtension;
const vk = @import("vulkan");
const VulkanContext = @import("../../graphics/vulkan/context.zig").VulkanContext;
const VulkanSwapchain = @import("../../graphics/vulkan/swapchain.zig");
const event = @import("../../event/event.zig");
const gl = @import("gl");
const Window = @import("../window.zig").Window;

const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/cursorfont.h");
    @cInclude("X11/Xcursor/Xcursor.h");
    @cInclude("X11/extensions/Xrandr.h");
    @cInclude("xkbcommon/xkbcommon.h");
    @cInclude("GL/glx.h");
    @cInclude("GL/gl.h");
});

const X = struct {
    XOpenDisplay: *const @TypeOf(c.XOpenDisplay),
    XCreateWindow: *const @TypeOf(c.XCreateWindow),
    XCloseDisplay: *const @TypeOf(c.XCloseDisplay),
    XMapWindow: *const @TypeOf(c.XMapWindow),
    XInternAtom: *const @TypeOf(c.XInternAtom),
    XSetWMProtocols: *const @TypeOf(c.XSetWMProtocols),
    XNextEvent: *const @TypeOf(c.XNextEvent),
    XPending: *const @TypeOf(c.XPending),
    XCreateColormap: *const @TypeOf(c.XCreateColormap),
    XStoreName: *const @TypeOf(c.XStoreName),
    XGetWindowAttributes: *const @TypeOf(c.XGetWindowAttributes),
    XDestroyWindow: *const @TypeOf(c.XDestroyWindow),
    XFlush: *const @TypeOf(c.XFlush),
    XSetErrorHandler: *const @TypeOf(c.XSetErrorHandler),

    pub fn load() !X {
        var xlib: X = undefined;
        var lib = try std.DynLib.open("libX11.so.6");

        inline for(@typeInfo(X).@"struct".fields) |field| {
            @field(xlib, field.name) = lib.lookup(field.type, field.name) orelse {
                log.fatal("Failed to load {s} dynamically", .{field.name});
            };
        }

        return xlib;
    }
};

const GLX = struct {
    glXChooseFBConfig: *const @TypeOf(c.glXChooseFBConfig),
    glXGetVisualFromFBConfig: *const @TypeOf(c.glXGetVisualFromFBConfig),
    glXCreateNewContext: *const @TypeOf(c.glXCreateNewContext),
    glXMakeContextCurrent: *const @TypeOf(c.glXMakeContextCurrent),
    glXMakeCurrent: *const @TypeOf(c.glXMakeCurrent),
    glXSwapBuffers: *const @TypeOf(c.glXSwapBuffers),
    glXDestroyContext: *const @TypeOf(c.glXDestroyContext),
    glXGetProcAddress: *const @TypeOf(c.glXGetProcAddress),
    glXGetProcAddressARB: *const @TypeOf(c.glXGetProcAddressARB),
    glXQueryExtensionsString: *const @TypeOf(c.glXQueryExtensionsString),
    
    pub fn load() !GLX {
        var glxlib: GLX = undefined;

        var lib = try std.DynLib.open("libGLX.so.0");

        inline for(@typeInfo(GLX).@"struct".fields) |field| {
            @field(glxlib, field.name) = lib.lookup(field.type, field.name) orelse {
                log.fatal("Failed to load {s} dynamically", .{field.name});
            };
        }

        return glxlib;
    }
};

fn callback(_: *c.Display, err: c.XErrorEvent) callconv(.c) c_int {
    log.debug("X error occurred: {}", .{err.error_code});

    return 0;
}

var x: X = undefined;
var glx: GLX = undefined;
var display: *c.Display = undefined;
var root: c.Window = undefined;

pub const WaylandWindow = struct {
    context: *const Context,
    node: event.EventNode,
    width: i32,
    height: i32,

    pub fn init() void {
    }

    pub fn set_size_screenspace(self: X11Window, width: i32, height: i32) void {
        _ = self;
        _ = width;
        _ = height;
    }

    pub fn get_size_pixels(self: X11Window) @Vector(2, i32) {
        _ = self;
        log.fatal("Not Implemented", .{});
    }
    
    pub fn create_window(context: *Context, allocator: std.mem.Allocator) *X11Window {
        _ = context;
        _ = allocator;
    }

    pub fn deinit() void {
    
    }

    pub fn update(window: *X11Window) void {
        _ = window;
    }

    pub fn get_event_node(self: *X11Window) *event.EventNode {
        return &self.node;
    }

    pub fn start_frame(self: X11Window) void {
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

    pub fn swap(self: *X11Window, ctx: *const Context) void {
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

    pub fn should_close(self: X11Window) bool {
        return self.pending_exit;
    }

    pub fn get_gl_loader(self: *const X11Window, gl_extension: []const u8) ?*anyopaque {
        _ = self;
        _ = gl_extension;
        log.fatal("GL Loader not implemented for wayland", .{});
    }

    pub fn get_proc_addr_fn(_: X11Window) *const anyopaque {
        // Load the Vulkan loader
        var lib = std.DynLib.open("libvulkan.so.1") catch {
            log.fatal("Failed to open libvulkan.so.1", .{});
        };

        const vkGetInstanceProcAddr = lib.lookup(*const anyopaque, "vkGetInstanceProcAddr") orelse {
            log.fatal("Failed to find vkGetInstanceProcAddr", .{});
        };
        return vkGetInstanceProcAddr;
    }

    pub fn get_vk_exts(_: X11Window, allocator: std.mem.Allocator) []VulkanExtension {
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

    pub fn create_vk_surface(self: X11Window, ctx: *const VulkanContext) vk.SurfaceKHR {
        _ = self;
        _ = ctx;
        log.fatal("create_vk_surface not implemented for wayland", .{});
    }
};

pub const X11Window = struct {
    context: *const Context,
    vi: *c.XVisualInfo,
    cmap: c.Colormap,
    swa: c.XSetWindowAttributes,
    gwa: c.XWindowAttributes,
    native: c.Window,
    gl_context: c.GLXContext,
    window_attributes: c.XWindowAttributes,
    pending_exit: bool,
    node: event.EventNode,
    width: i32,
    height: i32,

    pub fn init() void {
        x = X.load() catch {
            log.fatal("Failed to load X libraries. Make sure they exist in $LD_LIBRARY_PATH", .{});
        };
        glx = GLX.load() catch {
            log.fatal("Failed to load GLX libraries. Make sure they exist in $LD_LIBRARY_PATH", .{});
        };
        const d = x.XOpenDisplay(null);

        if(d == null) {
            log.fatal("Failed to open default X display", .{});
        }

        display = d.?;

        root = c.DefaultRootWindow(display);

    }

    pub fn set_size_screenspace(self: X11Window, width: i32, height: i32) void {
        _ = self;
        _ = width;
        _ = height;
    }

    pub fn get_size_pixels(self: X11Window) @Vector(2, i32) {
        return .{self.width, self.height};
    }
    
    pub fn create_window(context: *Context, allocator: std.mem.Allocator) *X11Window {
        _ = x.XSetErrorHandler(@ptrCast(&callback));

        var self: *X11Window = allocator.create(X11Window) catch unreachable;

        self.node = event.EventNode.init(allocator, self, &.{});
        self.width = 800;
        self.height = 600;

        self.context = context;

        var fbc: [*c]c.GLXFBConfig = undefined;

        var screen: c_int = undefined;
        var depth: c_int = undefined;
        var visual: [*c]c.Visual = undefined;

        if(context.* == .OPEN_GL) {
            var att = [_]c.GLint {
                c.GLX_X_RENDERABLE, 1,
                c.GLX_DRAWABLE_TYPE, c.GLX_WINDOW_BIT,
                c.GLX_RENDER_TYPE, c.GLX_RGBA_BIT,
                c.GLX_X_VISUAL_TYPE, c.GLX_TRUE_COLOR,
                c.GLX_RED_SIZE, 8,
                c.GLX_GREEN_SIZE, 8,
                c.GLX_BLUE_SIZE, 8,
                c.GLX_DEPTH_SIZE, 24,
                c.GLX_DOUBLEBUFFER, c.True,
                c.None,
            };

            // TODO, this only needs to be done for a gl context
            var count: c_int = 0;
            fbc = glx.glXChooseFBConfig(display, c.DefaultScreen(display), @ptrCast(&att), &count);
            if(count == 0) {
                log.fatal("No valid frame buffer config found", .{});
            }
            self.vi = glx.glXGetVisualFromFBConfig(display, fbc[0]) orelse {
                log.fatal("Failed to get visual for window", .{});
            };

            screen = self.vi.screen;
            depth = self.vi.depth;
            visual = self.vi.visual;
        } else {
            screen = c.DefaultScreen(display);
            depth = c.DefaultDepth(display, screen);
            visual = c.DefaultVisual(display, screen);

        }
        self.cmap = x.XCreateColormap(display, c.RootWindow(display, screen), visual, c.AllocNone);
        self.swa.colormap = self.cmap;
        self.swa.event_mask = c.ExposureMask | c.KeyPressMask | c.StructureNotifyMask;

        self.native = x.XCreateWindow(display, root, 0, 0, 600, 800, 0, depth, c.InputOutput, visual, c.CWColormap | c.CWEventMask, &self.swa);
        
        _ = x.XStoreName(display, self.native, "Engine");
        _ = x.XMapWindow(display, self.native);
        
        if(context.* == .OPEN_GL) {
            const glXCreateContextAttribsARB: c.PFNGLXCREATECONTEXTATTRIBSARBPROC = @ptrCast(glx.glXGetProcAddress("glXCreateContextAttribsARB"));

            const context_attribs = [_]c_int {
                c.GLX_CONTEXT_MAJOR_VERSION_ARB, 4,
                c.GLX_CONTEXT_MINOR_VERSION_ARB, 6,
                c.GLX_CONTEXT_PROFILE_MASK_ARB, c.GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                c.None,
            };

            _ = x.XFlush(display);

            self.gl_context = glXCreateContextAttribsARB.?(display, fbc[0], null, c.True, @ptrCast(&context_attribs));
            if(self.gl_context == null) {
                log.fatal("Failed to create gl context with glx", .{});
            }

            _ = glx.glXMakeCurrent(display, self.native, self.gl_context);

            log.debug("Made context current!", .{});
        }

        return self;
    }

    pub fn deinit() void {
        x.XCloseDisplay(display);
    }

    pub fn update(window: *X11Window) void {
        while(x.XPending(display) > 0) {
            var e: c.XEvent = undefined;
            _ = x.XNextEvent(display, @ptrCast(&e));
            
            switch(e.type) {
                c.ConfigureNotify => {
                    const cfg = e.xconfigure;
                    _ = window.node.handle_event_at_root(event.window.WindowResizeEvent, &.{
                        .width = cfg.width,
                        .height = cfg.height,
                    });
                    window.width = cfg.width;
                    window.height = cfg.height;
                },
                c.Expose => {
                    const cfg = e.xexpose;
                    _ = window.node.handle_event_at_root(event.window.WindowResizeEvent, &.{
                        .width = cfg.width,
                        .height = cfg.height,
                    });
                    window.width = cfg.width;
                    window.height = cfg.height;
                },
                else => {
                    log.warn("Unhandled x11 event type: {}", .{e.type});
                }
            }
        }
    }

    pub fn set_current_context(self: X11Window, context: Context) void {
        switch(context) {
            .OPEN_GL => {
                _ = self;
                //_ = glx.glXMakeCurrent(display, self.native, self.gl_context);
            },
            else => {},
        }
    }

    pub fn get_event_node(self: *X11Window) *event.EventNode {
        return &self.node;
    }

    pub fn start_frame(self: X11Window) void {
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

    pub fn swap(self: *X11Window, ctx: *const Context) void {
        switch(ctx.*) {
            .OPEN_GL => {
                glx.glXSwapBuffers(display, self.native);
            },
            .VULKAN => {
                ctx.VULKAN.swapchain.swap(&Window{ .linux = self });
            },
            else => {},
        }
    }

    pub fn should_close(self: X11Window) bool {
        return self.pending_exit;
    }

    pub fn get_gl_loader(self: *const X11Window, gl_extension: []const u8) ?*anyopaque {
        _ = self;
        return @ptrCast(@constCast(glx.glXGetProcAddressARB(@ptrCast(gl_extension.ptr))));
    }

    pub fn get_proc_addr_fn(_: X11Window) *const anyopaque {
        // Load the Vulkan loader
        var lib = std.DynLib.open("libvulkan.so.1") catch {
            log.fatal("Failed to open libvulkan.so.1", .{});
        };

        const vkGetInstanceProcAddr = lib.lookup(*const anyopaque, "vkGetInstanceProcAddr") orelse {
            log.fatal("Failed to find vkGetInstanceProcAddr", .{});
        };
        return vkGetInstanceProcAddr;
    }

    pub fn get_vk_exts(_: X11Window, allocator: std.mem.Allocator) []VulkanExtension {
        var extensions = allocator.alloc(VulkanExtension, 2) catch unreachable;
        extensions[0] = VulkanExtension{
            .name = "VK_KHR_surface",
            .required = true,
        };
        extensions[1] = VulkanExtension{
            .name = "VK_KHR_xlib_surface",
            .required = true,
        };
        return extensions;
    }

    pub fn create_vk_surface(self: X11Window, ctx: *const VulkanContext) vk.SurfaceKHR {
        const surfaceCreateInfo = vk.XlibSurfaceCreateInfoKHR{
            .dpy = @ptrCast(display),
            .window = self.native,
        };

        return ctx.instance.instance.createXlibSurfaceKHR(@ptrCast(&surfaceCreateInfo), null) catch {
            log.fatal("Failed to create XLib surface", .{});
        };
    }
};
