const std = @import("std");
const context = @import("context.zig");
const opengl = @import("opengl/shader.zig");
const vulkan = @import("vulkan/shader.zig");
const log = @import("../utils/log.zig");
const BufferLayout = @import("type.zig").BufferLayout;
const RenderTarget = @import("target.zig").RenderTarget;
const UniformBuffer = @import("buffer.zig").UniformBuffer;

/// An error that occurs while compiling or linking a shader pipeline.
pub const ShaderError = error{
    /// An individual shader stage failed to compile
    CompilationError,
    /// The pipeline failed to link all shader stages
    LinkingError,
};

// TODO: Replace with an asset manager
fn read_shader_file(comptime path: []const u8) ![]const u8 {
    var file = std.fs.cwd().openFile("assets/" ++ path, .{}) catch {
        log.err("Failed to open shader: {s}", .{try std.fs.cwd().realpathAlloc(std.heap.page_allocator, ".")});
        return undefined;
    };
    defer file.close();

    const data = try file.readToEndAlloc(std.heap.page_allocator, 65536);
    log.debug("Loaded shader file of size: {}", .{data.len});
    return data;
}

/// A vertex shader
pub const VertexShader = union(context.API) {
    OPEN_GL: opengl.OpenGLVertexShader,
    VULKAN: vulkan.VulkanVertexShader,
    NONE: void,

    /// Create a `VertexShader`
    ///
    /// **Parameter** `ctx`: The rendering context to create the shader for.
    /// **Parameter** `name`: The name of the shader file to read.
    /// **Returns** The created shader
    /// **Error** `CompilationError` the shader failed to compile.
    pub fn init(ctx: *const context.Context, comptime name: []const u8) ShaderError!VertexShader {
        const shader_data = read_shader_file(name ++ ".vert") catch return ShaderError.CompilationError;
        defer std.heap.page_allocator.free(shader_data);

        return switch (ctx.*) {
            .OPEN_GL => VertexShader{
                .OPEN_GL = opengl.OpenGLVertexShader.init(ctx.OPEN_GL, shader_data) catch {
                    return ShaderError.CompilationError;
                },
            },
            .VULKAN => VertexShader{
                .VULKAN = vulkan.VulkanVertexShader.init(ctx.VULKAN, shader_data) catch {
                    return ShaderError.CompilationError;
                },
            },
            .NONE => VertexShader{
                .NONE = {},
            },
        };
    }

    /// Destroy the given shader
    pub fn deinit(self: VertexShader) void {
        switch (self) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            .VULKAN => self.VULKAN.deinit(),
            inline else => log.not_implemented("VertexShader::deinit", self),
        }
    }
};

/// A fragment shader
pub const FragmentShader = union(context.API) {
    OPEN_GL: opengl.OpenGLFragmentShader,
    VULKAN: vulkan.VulkanFragmentShader,
    NONE: void,

    /// Create a `FragmentShader`
    ///
    /// **Parameter** `ctx`: The rendering context to create the shader for.
    /// **Parameter** `name`: The name of the shader file to read.
    /// **Returns** The created shader
    /// **Error** `CompilationError`: the shader failed to compile.
    pub fn init(ctx: *const context.Context, comptime name: []const u8) ShaderError!FragmentShader {
        const shader_data = read_shader_file(name ++ ".frag") catch return ShaderError.CompilationError;
        defer std.heap.page_allocator.free(shader_data);

        return switch (ctx.*) {
            .OPEN_GL => FragmentShader{
                .OPEN_GL = opengl.OpenGLFragmentShader.init(ctx.OPEN_GL, shader_data) catch {
                    return ShaderError.CompilationError;
                },
            },
            .VULKAN => FragmentShader{
                .VULKAN = vulkan.VulkanFragmentShader.init(ctx.VULKAN, shader_data) catch {
                    return ShaderError.CompilationError;
                },
            },
            .NONE => FragmentShader{
                .NONE = {},
            },
        };
    }

    /// Destroy the given shader
    pub fn deinit(self: FragmentShader) void {
        switch (self) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            .VULKAN => self.VULKAN.deinit(),
            inline else => log.not_implemented("FragmentShader::deinit", self),
        }
    }
};

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
        vertex_shader: *const VertexShader,
        fragment_shader: *const FragmentShader,
        buffer_layout: *const BufferLayout,
        bindings: *const ShaderBindingSet,
    ) ShaderError!Pipeline {
        return switch (ctx.*) {
            .OPEN_GL => Pipeline{
                .OPEN_GL = try opengl.OpenGLPipeline.init(&vertex_shader.OPEN_GL, &fragment_shader.OPEN_GL, buffer_layout, &bindings.OPEN_GL),
            },
            .VULKAN => Pipeline{
                .VULKAN = try vulkan.VulkanPipeline.init(ctx.VULKAN, vertex_shader.VULKAN, fragment_shader.VULKAN, buffer_layout, &bindings.VULKAN),
            },
            .NONE => Pipeline{
                .NONE = {},
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

pub const ShaderBindingType = enum {
    UNIFORM_BUFFER,
};

pub const ShaderStage = enum {
    VERTEX_SHADER,
    FRAGMENT_SHADER,
};

pub const ShaderBindingElement = union(ShaderBindingType) {
    UNIFORM_BUFFER: *UniformBuffer,
};

pub const ShaderBinding = struct {
    element: ShaderBindingElement,
    point: u32,
    stage: ShaderStage,
};

pub const ShaderBindingSet = union(context.API) {
    OPEN_GL: opengl.OpenGLShaderBindingSet,
    VULKAN: vulkan.VulkanShaderBindingSet,
    NONE: void,

    pub fn init(ctx: *const context.Context, bindings: []const ShaderBinding) ShaderBindingSet {
        return switch(ctx.*) {
            .OPEN_GL => .{
                .OPEN_GL = opengl.OpenGLShaderBindingSet.init(ctx.OPEN_GL, bindings),
            },
            .VULKAN => .{
                .VULKAN = vulkan.VulkanShaderBindingSet.init(ctx.VULKAN, bindings),
            },
            inline else => {
                log.not_implemented("ShaderBindingSet::init", ctx.*);
                unreachable;
            }
        };
    }
};
