const context = @import("context.zig");
const opengl = @import("opengl/shader.zig");
const vulkan = @import("vulkan/shader.zig");
const none = @import("none/shader.zig");
const log = @import("../utils/log.zig");

pub const ShaderError = error{ CompilationError, LinkingError };

pub const VertexShader = union(context.API) {
    OPEN_GL: opengl.OpenGLVertexShader,
    VULKAN: vulkan.VulkanVertexShader,
    NONE: none.NoneVertexShader,

    pub fn init(ctx: *const context.Context, src: []const u8) ShaderError!VertexShader {
        return switch (ctx.*) {
            .OPEN_GL => VertexShader{
                .OPEN_GL = opengl.OpenGLVertexShader.init(src) catch {
                    return ShaderError.CompilationError;
                },
            },
            .VULKAN => VertexShader{
                .VULKAN = vulkan.VulkanVertexShader.init(),
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

    pub fn init(ctx: *const context.Context, src: []const u8) ShaderError!FragmentShader {
        return switch (ctx.*) {
            .OPEN_GL => FragmentShader{
                .OPEN_GL = opengl.OpenGLFragmentShader.init(src) catch {
                    return ShaderError.CompilationError;
                },
            },
            .VULKAN => FragmentShader{
                .VULKAN = vulkan.VulkanFragmentShader.init(),
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

    pub fn init(ctx: *const context.Context, vertex_shader: *const VertexShader, fragment_shader: *const FragmentShader) ShaderError!Pipeline {
        return switch (ctx.*) {
            .OPEN_GL => Pipeline{
                .OPEN_GL = opengl.OpenGLPipeline.init(&vertex_shader.OPEN_GL, &fragment_shader.OPEN_GL) catch {
                    return ShaderError.LinkingError;
                },
            },
            .VULKAN => Pipeline{
                .VULKAN = vulkan.VulkanPipeline.init(),
            },
            .NONE => Pipeline{
                .NONE = none.NonePipeline.init(),
            },
        };
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
