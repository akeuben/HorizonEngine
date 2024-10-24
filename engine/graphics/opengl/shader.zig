const gl = @import("gl");
const ShaderError = @import("../shader.zig").ShaderError;
const log = @import("../../utils/log.zig");
const BufferLayout = @import("../type.zig").BufferLayout;

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
    gl_array: u32,
    program: u32,

    pub fn init(vertex_shader: *const OpenGLVertexShader, fragment_shader: *const OpenGLFragmentShader, buffer_layout: *const BufferLayout) ShaderError!OpenGLPipeline {
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

        // Create associated VAO
        var gl_array: u32 = 0;
        gl.genVertexArrays(1, &gl_array);

        for (buffer_layout.elements, 0..) |element, i| {
            gl.vertexAttribPointer(@intCast(i), @intCast(element.length), gl.FLOAT, gl.FALSE, @intCast(buffer_layout.size), @ptrFromInt(element.offset));
            gl.enableVertexAttribArray(@intCast(i));
        }
        gl.disableVertexAttribArray(0);

        return OpenGLPipeline{
            .program = program,
            .gl_array = gl_array,
        };
    }

    pub fn deinit(self: OpenGLPipeline) void {
        gl.deleteProgram(self.program);
    }

    pub fn bind(self: OpenGLPipeline) void {
        gl.bindVertexArray(self.gl_array);
        gl.useProgram(self.program);
    }
};
