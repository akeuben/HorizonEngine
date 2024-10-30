const std = @import("std");
const context = @import("context.zig");
const opengl = @import("opengl/shader.zig");
const vulkan = @import("vulkan/shader.zig");
const none = @import("none/shader.zig");
const log = @import("../utils/log.zig");
const BufferLayout = @import("type.zig").BufferLayout;
const RenderTarget = @import("target.zig").RenderTarget;

pub const ShaderError = error{ CompilationError, LinkingError };

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

pub const VertexShader = union(context.API) {
    OPEN_GL: opengl.OpenGLVertexShader,
    VULKAN: vulkan.VulkanVertexShader,
    NONE: none.NoneVertexShader,

    pub fn init(ctx: *const context.Context, comptime name: []const u8) ShaderError!VertexShader {
        const shader_data = read_shader_file(name ++ ".vert.spv") catch return ShaderError.CompilationError;
        defer std.heap.page_allocator.free(shader_data);

        return switch (ctx.*) {
            .OPEN_GL => VertexShader{
                .OPEN_GL = opengl.OpenGLVertexShader.init(shader_data) catch {
                    return ShaderError.CompilationError;
                },
            },
            .VULKAN => VertexShader{
                .VULKAN = vulkan.VulkanVertexShader.init(&ctx.VULKAN, shader_data) catch {
                    return ShaderError.CompilationError;
                },
            },
            .NONE => VertexShader{
                .NONE = none.NoneVertexShader.init(),
            },
        };
    }

    pub fn deinit(self: VertexShader) void {
        switch (self) {
            inline else => |case| case.deinit(),
        }
    }
};

pub const FragmentShader = union(context.API) {
    OPEN_GL: opengl.OpenGLFragmentShader,
    VULKAN: vulkan.VulkanFragmentShader,
    NONE: none.NoneFragmentShader,

    pub fn init(ctx: *const context.Context, comptime name: []const u8) ShaderError!FragmentShader {
        const shader_data = read_shader_file(name ++ ".frag.spv") catch return ShaderError.CompilationError;
        defer std.heap.page_allocator.free(shader_data);

        return switch (ctx.*) {
            .OPEN_GL => FragmentShader{
                .OPEN_GL = opengl.OpenGLFragmentShader.init(shader_data) catch {
                    return ShaderError.CompilationError;
                },
            },
            .VULKAN => FragmentShader{
                .VULKAN = vulkan.VulkanFragmentShader.init(&ctx.VULKAN, shader_data) catch {
                    return ShaderError.CompilationError;
                },
            },
            .NONE => FragmentShader{
                .NONE = none.NoneFragmentShader.init(),
            },
        };
    }

    pub fn deinit(self: FragmentShader) void {
        switch (self) {
            inline else => |case| case.deinit(),
        }
    }
};

pub const Pipeline = union(context.API) {
    OPEN_GL: opengl.OpenGLPipeline,
    VULKAN: vulkan.VulkanPipeline,
    NONE: none.NonePipeline,

    pub fn init(ctx: *const context.Context, vertex_shader: *const VertexShader, fragment_shader: *const FragmentShader, buffer_layout: *const BufferLayout, target: *const RenderTarget) ShaderError!Pipeline {
        return switch (ctx.*) {
            .OPEN_GL => Pipeline{
                .OPEN_GL = opengl.OpenGLPipeline.init(&vertex_shader.OPEN_GL, &fragment_shader.OPEN_GL, buffer_layout) catch {
                    return ShaderError.LinkingError;
                },
            },
            .VULKAN => Pipeline{
                .VULKAN = vulkan.VulkanPipeline.init(&ctx.VULKAN, vertex_shader.VULKAN, fragment_shader.VULKAN, buffer_layout, target.VULKAN) catch {
                    return ShaderError.LinkingError;
                },
            },
            .NONE => Pipeline{
                .NONE = none.NonePipeline.init(),
            },
        };
    }

    pub fn init_inline(ctx: *const context.Context, comptime name: []const u8, buffer_layout: *const BufferLayout, target: *const RenderTarget) ShaderError!Pipeline {
        const vertex_shader = try VertexShader.init(ctx, name);
        defer vertex_shader.deinit();
        const fragment_shader = try FragmentShader.init(ctx, name);
        defer fragment_shader.deinit();

        return Pipeline.init(ctx, &vertex_shader, &fragment_shader, buffer_layout, target);
    }

    pub fn deinit(self: Pipeline) void {
        switch (self) {
            inline else => |case| case.deinit(),
        }
    }

    pub fn bind(self: Pipeline) void {
        switch (self) {
            inline else => |case| case.bind(),
        }
    }
};
