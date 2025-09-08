const gl = @import("gl");
const _shader = @import("../shader.zig");
const ShaderError = _shader.ShaderError;
const ShaderBindingLayoutElement = _shader.ShaderBindingLayoutElement;
const ShaderStage = _shader.ShaderStage;
const log = @import("../../utils/log.zig");
const BufferLayout = @import("../type.zig").BufferLayout;
const Context = @import("context.zig").OpenGLContext;
const BoundShaderBinding = @import("../shader.zig").BoundShaderBinding;
const CreateInfoShaderBindingElement = @import("../shader.zig").CreateInfoShaderBindingElement;
const ShaderBindingLayout = @import("../shader.zig").ShaderBindingLayout;
const ShaderBindingElement = @import("../shader.zig").ShaderBindingElement;

const shaderc = @import("shaderc");

var compiler: shaderc.Compiler = undefined;
var initialized = false;

pub const OpenGLVertexShader = struct {
    shader: u32,

    pub fn init(ctx: *const Context, sourceCode: []const u8) ShaderError!OpenGLVertexShader {
        if(!initialized) {
            compiler = shaderc.Compiler.initialize();
            initialized = true;
        }
        const options = shaderc.CompileOptions.initialize();
        defer options.release();
        options.setOptimizationLevel(shaderc.OptimizationLevel.Zero);
        options.setSourceLanguage(shaderc.SourceLanguage.GLSL);
        options.setVersion(shaderc.Env.Target.OpenGL, shaderc.Env.VulkanVersion.@"gl45");
        const result = compiler.compileIntoSpv(ctx.allocator, sourceCode, shaderc.ShaderKind.Vertex, "main", options) catch |e| {
            log.err("Failed to compile vertex shader: {}", .{e});
            return ShaderError.CompilationError;
        };
        if(result.getCompilationStatus() == .Success) {
            log.debug("Compiled (1) vertex shader.", .{});
        } else {
            log.err("Failed to compile vertex shader: {s}", .{result.getErrorMessage()});
            return ShaderError.CompilationError;
        }
        const data = result.getBytes();
        const shader = gl.createShader(gl.VERTEX_SHADER);
        gl.shaderBinary(1, @ptrCast(&shader), gl.GL_ARB_gl_spirv.SHADER_BINARY_FORMAT_SPIR_V_ARB, @ptrCast(data.ptr), @intCast(data.len));
        gl.GL_ARB_gl_spirv.specializeShaderARB(shader, "main", 0, 0, 0);

        var success: i32 = 0;
        var error_log: [512]u8 = undefined;
        gl.getShaderiv(shader, gl.COMPILE_STATUS, &success);

        if (success != gl.TRUE) {
            gl.getShaderInfoLog(shader, 512, null, &error_log[0]);
            log.err("GL: Failed to compile vertex shader: {s}", .{error_log});
            //return ShaderError.CompilationError;
        }

        return OpenGLVertexShader{ .shader = shader };
    }

    pub fn deinit(self: OpenGLVertexShader) void {
        gl.deleteShader(self.shader);
    }
};

pub const OpenGLFragmentShader = struct {
    shader: u32,

    pub fn init(ctx: *const Context, sourceCode: []const u8) ShaderError!OpenGLFragmentShader {
        if(!initialized) {
            compiler = shaderc.Compiler.initialize();
            initialized = true;
        }
        const options = shaderc.CompileOptions.initialize();
        defer options.release();
        options.setOptimizationLevel(shaderc.OptimizationLevel.Zero);
        options.setSourceLanguage(shaderc.SourceLanguage.GLSL);
        options.setVersion(shaderc.Env.Target.OpenGL, shaderc.Env.VulkanVersion.@"gl45");
        const result = compiler.compileIntoSpv(ctx.allocator, sourceCode, shaderc.ShaderKind.Fragment, "main", options) catch |e| {
            log.err("Failed to compile fragment shader: {}", .{e});
            return ShaderError.CompilationError;
        };
        if(result.getCompilationStatus() == .Success) {
            log.debug("Compiled (1) fragment shader.", .{});
        } else {
            log.err("Failed to compile fragment shader: {s}", .{result.getErrorMessage()});
            return ShaderError.CompilationError;
        }
        const data = result.getBytes();
        const shader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderBinary(1, @ptrCast(&shader), gl.GL_ARB_gl_spirv.SHADER_BINARY_FORMAT_SPIR_V_ARB, @ptrCast(data.ptr), @intCast(data.len));
        gl.GL_ARB_gl_spirv.specializeShaderARB(shader, "main", 0, 0, 0);

        var success: i32 = 0;
        var error_log: [512]u8 = undefined;
        gl.getShaderiv(shader, gl.COMPILE_STATUS, &success);

        if (success != gl.TRUE) {
            gl.getShaderInfoLog(shader, 512, null, &error_log[0]);
            log.err("GL: Failed to compile fragment shader: {s}", .{error_log});
            //return ShaderError.CompilationError;
        }

        return OpenGLFragmentShader{ .shader = shader };
    }

    pub fn deinit(self: OpenGLFragmentShader) void {
        gl.deleteShader(self.shader);
    }
};

pub const OpenGLPipeline = struct {
    program: u32,

    pub fn init(vertex_shader: *const OpenGLVertexShader, fragment_shader: *const OpenGLFragmentShader, _: *const BufferLayout, _: *const OpenGLShaderBindingSet) ShaderError!OpenGLPipeline {
        const program: u32 = gl.createProgram();
        gl.attachShader(program, vertex_shader.shader);
        gl.attachShader(program, fragment_shader.shader);
        gl.linkProgram(program);

        var success: i32 = 0;
        var error_log: [512]u8 = undefined;
        gl.getProgramiv(program, gl.LINK_STATUS, &success);

        if (success != gl.TRUE) {
            gl.getProgramInfoLog(program, 512, null, &error_log[0]);
            log.err("GL: Failed to link shader program: {s}", .{error_log});
            return ShaderError.LinkingError;
        }

        return OpenGLPipeline{
            .program = program,
        };
    }

    pub fn deinit(self: OpenGLPipeline) void {
        gl.deleteProgram(self.program);
    }
};

fn create_element(binding: *const ShaderBindingLayoutElement, element: *anyopaque) ShaderBindingElement {
    return switch(binding.binding_type) {
        .UNIFORM_BUFFER => ShaderBindingElement{
            .UNIFORM_BUFFER = @ptrCast(@alignCast(element)),
        },
        .IMAGE_SAMPLER => ShaderBindingElement{
            .IMAGE_SAMPLER = @ptrCast(@alignCast(element)),
        }
    };
}

pub const OpenGLShaderBindingSet = struct {
    ctx: *const Context,
    bindings: []const BoundShaderBinding,
    count: u32,

    pub fn init(ctx: *const Context, layout: *const OpenGLShaderBindingLayout, elements: []const CreateInfoShaderBindingElement) OpenGLShaderBindingSet {
        const bindings = ctx.allocator.alloc(BoundShaderBinding, elements.len) catch unreachable;
        var i: u32 = 0;
        for(elements) |element| {
            var b: ?BoundShaderBinding = null;
            for(layout.bindings) |binding| {
                if(binding.point == element.point) {
                    b = BoundShaderBinding{
                        .element = create_element(&binding, element.element),
                        .layout = binding,
                    };
                }
            }
            if(b == null) {
                log.warn("Tried to bind an element that does not have a binding point in the layout, or is of the incorrect type at point {}", .{element.point});
                continue;
            }
            bindings[i] = b.?;
            i += 1;
        }

        return OpenGLShaderBindingSet{
            .ctx = ctx,
            .count = i,
            .bindings = bindings,
        };
    }

    pub fn deinit(self: *const OpenGLShaderBindingSet) void {
        self.ctx.allocator.free(self.bindings);
    }
};

pub const OpenGLShaderBindingLayout = struct {
    bindings: []const ShaderBindingLayoutElement,

    pub fn init(_: *const Context, bindings: []const ShaderBindingLayoutElement) OpenGLShaderBindingLayout {
        return OpenGLShaderBindingLayout {
            .bindings = bindings,
        };
    }
};
