///! This module is responsible for handling a graphic API context
const std = @import("std");
const opengl = @import("opengl/context.zig");
const vulkan = @import("vulkan/context.zig");
const Window = @import("../platform/window.zig").Window;
const Pipeline = @import("shader.zig").Pipeline;
const VertexBuffer = @import("buffer.zig").VertexBuffer;
const RenderTarget = @import("target.zig").RenderTarget;
const log = @import("../utils/log.zig");
const event = @import("../event/event.zig");

/// A Graphics API
pub const API = enum { OPEN_GL, VULKAN, NONE };

/// The context for a graphics API
///
/// Currently supports OpenGL, Vulkan, and a headless renderer.
pub const Context = union(API) {
    OPEN_GL: *opengl.OpenGLContext,
    VULKAN: *vulkan.VulkanContext,
    NONE: void,

    /// Initializes a new OpenGL context
    ///
    /// **Parameter** `allocator`: The allocator to use for the duration of this context's lifetime.
    pub fn init_open_gl(allocator: std.mem.Allocator, options: ContextCreationOptions) Context {
        return Context{
            .OPEN_GL = opengl.OpenGLContext.init(allocator, options),
        };
    }

    /// Initializes a new Vulkan context
    ///
    /// **Parameter** `allocator`: The allocator to use for the duration of this context's lifetime.
    pub fn init_vulkan(allocator: std.mem.Allocator, options: ContextCreationOptions) Context {
        return Context{
            .VULKAN = vulkan.VulkanContext.init(allocator, options),
        };
    }

    /// Initializes a new headless context
    ///
    /// **Parameter** `allocator`: The allocator to use for the duration of this context's lifetime.
    pub fn init_none(_: std.mem.Allocator, _: ContextCreationOptions) Context {
        return Context{
            .NONE = {},
        };
    }

    /// Destroys the given context. Ensure that all
    /// graphics objects related to thsi context are destroyed
    /// prior to destroying the context.
    ///
    /// **Parameter** `self`: The context to destroy.
    pub fn deinit(self: *Context) void {
        switch (self.*) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            .VULKAN => self.VULKAN.deinit(),
            inline else => log.not_implemented("Context::deinit", self.*),
        }
    }

    /// Binds a context to a window. This is required to load the API, and as such,
    /// the api cannot be used until it is loaded.
    ///
    /// **Parameter** `self`: The context to load.
    /// **Parameter** `window`: The window/surface providing the API bindings.
    pub fn load(self: *Context, window: *const Window) void {
        switch (self.*) {
            .OPEN_GL => opengl.OpenGLContext.load(self.OPEN_GL, window),
            .VULKAN => vulkan.VulkanContext.load(self.VULKAN, window),
            inline else => log.not_implemented("Context::load", self.*),
        }
    }

    /// Get the default target for the rendering context. Rendering a scene
    /// requires rendering to some target.
    ///
    /// **Parameter** `self`: The context to get the rendering target for.
    /// **Returns** The default rendering target for the given context.
    pub fn get_target(self: *Context) RenderTarget {
        return switch (self.*) {
            .OPEN_GL => RenderTarget{
                .OPEN_GL = self.OPEN_GL.get_target(),
            },
            .VULKAN => RenderTarget{
                .VULKAN = self.VULKAN.get_target(),
            },
            .NONE => RenderTarget{
                .NONE = {},
            },
        };
    }

    pub fn get_event_node(self: *Context) ?*event.EventNode {
        return switch(self.*) {
            .OPEN_GL => self.OPEN_GL.get_event_node(),
            .VULKAN => self.VULKAN.get_event_node(),
            inline else => {
                log.not_implemented("Context::get_event_node", self.*);
                return null;
            },
        };
    }
};

/// Context Creation Options
pub const ContextCreationOptions = struct {
    /// Whether to enable debug logging for the context
    use_debug: bool,
};
