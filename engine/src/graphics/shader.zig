const std = @import("std");
const context = @import("context.zig");
const opengl = @import("opengl/shader.zig");
const vulkan = @import("vulkan/shader.zig");
const log = @import("../utils/log.zig");
const slang = @import("slang");
const BufferLayout = @import("type.zig").BufferLayout;
const RenderTarget = @import("target.zig").RenderTarget;
const UniformBuffer = @import("buffer.zig").UniformBuffer;
const TextureSampler = @import("texture.zig").TextureSampler;

/// An error that occurs while compiling or linking a shader pipeline.
pub const ShaderError = error{
    ReadError,
    /// An individual shader stage failed to compile
    CompilationError,
    /// The pipeline failed to link all shader stages
    LinkingError,
};

// TODO: Replace with an asset manager
fn read_shader_file(allocator: std.mem.Allocator, path: []const u8) ![:0]const u8 {
    var file = std.fs.cwd().openFile(path, .{}) catch {
        const p = try std.fs.cwd().realpathAlloc(allocator, ".");
        defer allocator.free(p);
        
        log.err("Failed to open shader: {s}", .{p});
        return ShaderError.ReadError;
    };
    defer file.close();

    const buffer: []u8 = try allocator.alloc(u8, 65536);
    defer allocator.free(buffer);
    var fileReader = file.reader(buffer);

    const reader = &fileReader.interface;

    const data = try reader.allocRemaining(allocator, .unlimited);

    const dataWithSentinal = try std.mem.concatWithSentinel(allocator, u8, &.{data}, 0);

    return dataWithSentinal;
}

/// A pipeline consisting of a vertex shader and a fragment shader
pub const Pipeline = union(context.API) {
    OPEN_GL: opengl.OpenGLPipeline,
    VULKAN: vulkan.VulkanPipeline,
    NONE: void,

    /// Create a `Pipeline` using a pre-existing vertex and fragment shader.
    ///
    /// **Parameter** `ctx`: The rendering context to create the pipeline for.
    /// **Parameter** `vertex_shader`: The vertex shader for the pipeline.
    /// **Parameter** `fragment_shader`: The fragment shader for the pipeline.
    /// **Parameter** `buffer_layout`: The layout of a vertex
    /// **Parameter** `target`: The target this pipeline will render to.
    /// **Returns** The created pipeline
    /// **Error** `LinkingError`: The pipeline failed to link.
    pub fn init(
        ctx: *const context.Context,
        name: []const u8,
        buffer_layout: *const BufferLayout,
    ) ShaderError!Pipeline {
        const allocator = ctx.getAllocator();
        const path = std.mem.concat(allocator, u8, &.{
            "assets/",
            name,
            ".slang"
        }) catch unreachable;
        defer allocator.free(path);
        const source = read_shader_file(allocator, path) catch return ShaderError.CompilationError;
        defer allocator.free(source);
        return switch (ctx.*) {
            .OPEN_GL => Pipeline{
                .NONE = {},
            },
            .VULKAN => Pipeline{
                //.VULKAN = try vulkan.VulkanPipeline.init(name, buffer_layout, &bindings.VULKAN),
                .VULKAN = vulkan.VulkanPipeline.init(ctx.VULKAN, source, buffer_layout) catch unreachable,
            },
            .NONE => Pipeline{
                .NONE = {},
            },
        };
    }

    pub fn getLayout(self: Pipeline) ShaderBindingLayout {
        return switch(self) {
            .VULKAN => .{
                .VULKAN = self.VULKAN.getLayout(),
            },
            else => .{
                .NONE = log.not_implemented("Pipeline::getLayout", self)
            },
        };
    }

    // Destroy the given pipeline
    pub fn deinit(self: Pipeline) void {
        switch (self) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            .VULKAN => self.VULKAN.deinit(),
            inline else => log.not_implemented("Pipeline::deinit", self),
        }
    }
};

pub const ShaderBindingLayoutElementType = enum {
    UNIFORM_BUFFER, IMAGE_SAMPLER
};

pub const ShaderBindingLayoutElement = struct {
    name: []const u8,
    type: ShaderBindingLayoutElementType,
    point: u32,
};

pub const ShaderBindingLayout = union(context.API) {
    OPEN_GL: void,
    VULKAN: vulkan.VulkanShaderBindingLayout,
    NONE: void,

    pub fn create(self: ShaderBindingLayout, elements: []const CreateInfoShaderBindingElement) ShaderBindingSet {
        return switch (self) {
            .VULKAN => .{
                .VULKAN = self.VULKAN.create(elements),
            },
            else => .{
                .NONE = log.not_implemented("ShaderBindingLayout::create", self),
            },
        };
    }
};

pub const ShaderBindingElement = union(ShaderBindingLayoutElementType) {
    UNIFORM_BUFFER: *UniformBuffer,
    IMAGE_SAMPLER: *TextureSampler,
};

pub const CreateInfoShaderBindingElement = struct {
    element: *anyopaque, 
    point: []const u8
};

pub const ShaderBindingSet = union(context.API) {
    OPEN_GL: void,
    VULKAN: vulkan.VulkanShaderBindingSet,
    NONE: void,

    pub fn deinit(self: *const ShaderBindingSet) void {
        switch(self.*) {
            inline else => log.not_implemented("ShaderBindingSet::deinit", self.*),
        }
    }
};
