const gl = @import("gl");
const _shader = @import("../shader.zig");
const ShaderError = _shader.ShaderError;
const ShaderBindingLayoutElement = _shader.ShaderBindingLayoutElement;
const ShaderStage = _shader.ShaderStage;
const log = @import("../../utils/log.zig");
const BufferLayout = @import("../type.zig").BufferLayout;
const Context = @import("context.zig").OpenGLContext;
const CreateInfoShaderBindingElement = @import("../shader.zig").CreateInfoShaderBindingElement;
const ShaderBindingLayout = @import("../shader.zig").ShaderBindingLayout;
const ShaderBindingElement = @import("../shader.zig").ShaderBindingElement;

const Slang = @import("../slang.zig").SlangSession(.glsl, "glsl_330");

const OpenGLShader = struct {
    shader: u32,

    fn init(sourceCode: []const u8, shaderType: c_uint) ShaderError!OpenGLShader {
        const shader = gl.createShader(shaderType);

        const strings = [_][*]const u8{sourceCode.ptr};
        const lengths = [_]gl.GLint{@intCast(sourceCode.len)};

        log.debug("Shader source: {s}", .{sourceCode});
        
        gl.shaderSource(shader, 1, @ptrCast(&strings), @ptrCast(&lengths));

        var success: i32 = 0;
        var error_log: [512]u8 = undefined;
        gl.getShaderiv(shader, gl.COMPILE_STATUS, &success);

        if (success != gl.TRUE) {
            gl.getShaderInfoLog(shader, 512, null, &error_log[0]);
            log.err("GL: Failed to compile vertex shader: {s}", .{error_log});
            return ShaderError.CompilationError;
        }

        return OpenGLShader{ .shader = shader };
    }

    fn deinit(self: OpenGLShader) void {
        gl.deleteShader(self.shader);
    }
};

pub const OpenGLPipeline = struct {

    program: u32,
    module: *Slang.Module,

    pub fn init(source: [:0]const u8, _: *const BufferLayout) ShaderError!OpenGLPipeline {
        const session = Slang.getSession() catch return ShaderError.CompilationError;
        const module = session.compileProgram("shader", source, &[_][*:0]const u8 {"vertex", "fragment"}) catch return ShaderError.CompilationError;

        const vertexSource = module.getEntryPointCode(0, 0, null) catch return ShaderError.LinkingError;
        const fragmentSource = module.getEntryPointCode(1, 0, null) catch return ShaderError.LinkingError;
        
        const program: u32 = gl.createProgram();

        const vertex_shader = try OpenGLShader.init(vertexSource.getBuffer(), gl.VERTEX_SHADER);
        defer vertex_shader.deinit();
        const fragment_shader = try OpenGLShader.init(fragmentSource.getBuffer(), gl.FRAGMENT_SHADER);
        defer fragment_shader.deinit();

        
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
            .module = undefined,
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
