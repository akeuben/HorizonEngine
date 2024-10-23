const gl = @import("gl");
const ShaderError = @import("../shader.zig").ShaderError;
const log = @import("../../utils/log.zig");

pub const OpenGLVertexShader = struct {
    shader: u32,

    pub fn init(data: []const u8) ShaderError!OpenGLVertexShader {
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

    pub fn init(data: []const u8) ShaderError!OpenGLFragmentShader {
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

    pub fn init(vertex_shader: *const OpenGLVertexShader, fragment_shader: *const OpenGLFragmentShader) ShaderError!OpenGLPipeline {
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

    pub fn bind(self: OpenGLPipeline) void {
        gl.useProgram(self.program);
    }
};
