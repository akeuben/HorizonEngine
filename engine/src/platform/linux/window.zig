const std = @import("std");
const log = @import("../../utils/log.zig");
const Context = @import("../../graphics/context.zig").Context;
const VulkanExtension = @import("../../graphics/vulkan/extension.zig").VulkanExtension;
const vk = @import("vulkan");
const VulkanContext = @import("../../graphics/vulkan/context.zig").VulkanContext;
const VulkanSwapchain = @import("../../graphics/vulkan/swapchain.zig");
const event = @import("../../event/event.zig");
const gl = @import("gl");

const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/cursorfont.h");
    @cInclude("X11/Xcursor/Xcursor.h");
    @cInclude("X11/extensions/Xrandr.h");
    @cInclude("xkbcommon/xkbcommon.h");
    @cInclude("GL/glx.h");
});

const X = struct {
    XOpenDisplay: *const @TypeOf(c.XOpenDisplay),
    XCreateWindow: *const @TypeOf(c.XCreateWindow),
    XCloseDisplay: *const @TypeOf(c.XCloseDisplay),
    XMapWindow: *const @TypeOf(c.XMapWindow),
    XInternAtom: *const @TypeOf(c.XInternAtom),
    XSetWMProtocols: *const @TypeOf(c.XSetWMProtocols),
    XNextEvent: *const @TypeOf(c.XNextEvent),
    XCreateColormap: *const @TypeOf(c.XCreateColormap),
    XStoreName: *const @TypeOf(c.XStoreName),
    XGetWindowAttributes: *const @TypeOf(c.XGetWindowAttributes),
    XDestroyWindow: *const @TypeOf(c.XDestroyWindow),
    XFlush: *const @TypeOf(c.XFlush),

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
    glXSwapBuffers: *const @TypeOf(c.glXSwapBuffers),
    glXDestroyContext: *const @TypeOf(c.glXDestroyContext),
    glXGetProcAddress: *const @TypeOf(c.glXGetProcAddress),
    
    pub fn load() !GLX {
        var glxlib: GLX = undefined;

        var lib = try std.DynLib.open("libGLX.so");

        inline for(@typeInfo(GLX).@"struct".fields) |field| {
            @field(glxlib, field.name) = lib.lookup(field.type, field.name) orelse {
                log.fatal("Failed to load {s} dynamically", .{field.name});
            };
        }

        return glxlib;
    }
};

var x: X = undefined;
var glx: GLX = undefined;
var display: *c.Display = undefined;
var root: c.Window = undefined;

pub const X11Window = struct {
    vi: *c.XVisualInfo,
    cmap: c.Colormap,
    swa: c.XSetWindowAttributes,
    gwa: c.XWindowAttributes,
    native: c.Window,
    gl_context: c.GLXContext,
    window_attributes: c.XWindowAttributes,
    pending_exit: bool,
    node: event.EventNode,

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
        _ = self;
        return .{0,0};
    }
    
    pub fn create_window(context: *Context, allocator: std.mem.Allocator) *X11Window {
        _ = context;

        var self: *X11Window = allocator.create(X11Window) catch unreachable;

        var att = [_]c.GLint {
            c.GLX_X_RENDERABLE, 1,
            c.GLX_DRAWABLE_TYPE, c.GLX_WINDOW_BIT,
            c.GLX_RENDER_TYPE, c.GLX_RGBA_BIT,
            c.GLX_X_VISUAL_TYPE, c.GLX_TRUE_COLOR,
            c.GLX_RED_SIZE, 8,
            c.GLX_GREEN_SIZE, 8,
            c.GLX_BLUE_SIZE, 8,
            c.GLX_ALPHA_SIZE, 8,
            c.GLX_DEPTH_SIZE, 24,
            c.GLX_DOUBLEBUFFER, 1,
            c.None,
        };

        // TODO, this only needs to be done for a gl context
        var count: c_int = 0;
        const fbc = glx.glXChooseFBConfig(display, c.DefaultScreen(display), @ptrCast(&att), &count);
        if(count == 0) {
            log.fatal("No valid frame buffer config found", .{});
        }
        self.vi = glx.glXGetVisualFromFBConfig(display, fbc[0]) orelse {
            log.fatal("Failed to get visual for window", .{});
        };
        self.cmap = x.XCreateColormap(display, root, self.vi.visual, c.AllocNone);
        self.swa.colormap = self.cmap;
        self.swa.event_mask = c.ExposureMask | c.KeyPressMask | c.StructureNotifyMask;

        self.native = x.XCreateWindow(display, root, 0, 0, 600, 800, 0, self.vi.depth, c.InputOutput, self.vi.visual, c.CWColormap | c.CWEventMask, &self.swa);
        
        _ = x.XMapWindow(display, self.native);

        _ = x.XStoreName(display, self.native, "Engine");
        
        self.gl_context = glx.glXCreateNewContext(display, fbc[0], c.GLX_RGBA_TYPE, null, 1);

        if(self.gl_context == null) {
            log.fatal("Failed to create GL context", .{});
        }

        if(glx.glXMakeContextCurrent(display, self.native, self.native, self.gl_context) == 0) {
            log.fatal("Failed to make context current", .{});
        }

        self.pending_exit = false;

        self.node = event.EventNode.init(allocator, self, &.{});

        var e: c.XEvent = undefined;
        while(true) {
            _ = x.XNextEvent(display, @ptrCast(&e));

            if(e.type == c.Expose) {
                _ = x.XGetWindowAttributes(display, self.native, @ptrCast(&self.gwa));
                break;
            }
        }
        
        return self;
    }

    pub fn deinit() void {
        x.XCloseDisplay(display);
    }

    pub fn update(window: *X11Window) void {
        var e: c.XEvent = undefined;
        _ = x.XNextEvent(display, @ptrCast(&e));
        
        switch(e.type) {
            c.ConfigureNotify => {
                const cfg = e.xconfigure;
                _ = window.node.handle_event_at_root(event.window.WindowResizeEvent, &.{
                    .width = cfg.width,
                    .height = cfg.height,
                });
            },
            c.Expose => {
                const cfg = e.xexpose;
                _ = window.node.handle_event_at_root(event.window.WindowResizeEvent, &.{
                    .width = cfg.width,
                    .height = cfg.height,
                });
            },
            else => {
                log.warn("Unhandled x11 event type: {}", .{e.type});
            }
        }
        
    }

    pub fn set_current_context(self: X11Window, context: Context) void {
        switch(context) {
            .OPEN_GL => {
                _ = glx.glXMakeContextCurrent(display, self.native, self.native, self.gl_context);
            },
            else => {},
        }
    }

    pub fn get_event_node(self: *X11Window) *event.EventNode {
        return &self.node;
    }

    pub fn start_frame(self: X11Window) void {
        _ = self;
    }

    pub fn swap(self: *X11Window, ctx: *const Context) void {
        switch(ctx.*) {
            .OPEN_GL => {
                glx.glXSwapBuffers(display, self.native);
                _ = x.XFlush(display);
            },
            else => {},
        }
    }

    pub fn should_close(self: X11Window) bool {
        return self.pending_exit;
    }

    pub fn get_gl_loader(self: X11Window, gl_extension: []const u8) ?*anyopaque {
        _ = self;
        return @ptrCast(@constCast(glx.glXGetProcAddress(@ptrCast(gl_extension.ptr))));
    }

    pub fn get_proc_addr_fn(self: X11Window) *const anyopaque {
        _ = self;
        return undefined;
    }

    pub fn get_vk_exts(self: X11Window, allocator: std.mem.Allocator) []VulkanExtension {
        _ = self;
        _ = allocator;
        return &.{};
    }

    pub fn create_vk_surface(self: X11Window, ctx: *const VulkanContext) vk.SurfaceKHR {
        _ = self;
        _ = ctx;
        return undefined;
    }
};
