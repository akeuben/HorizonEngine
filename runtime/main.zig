const std = @import("std");

const engine = @import("engine");

const w = engine.platform.window;
const types = engine.graphics.types;
const c = engine.graphics.context;
const b = engine.graphics.buffer;
const log = engine.log;
const gl = engine.gl;

const vertices: []const f32 = &[_]f32{
    -0.5, -0.5, 0.0,
    0.5,  -0.5, 0.0,
    0.0,  0.5,  0.0,
};

const vertex_shader_src: []const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\
    \\void main() {
    \\  gl_Position = vec4(aPos, 1.0);
    \\}
;

const fragment_shader_src: []const u8 =
    \\#version 330 core
    \\out vec4 FragColor;
    \\
    \\void main() {
    \\  FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
    \\}
;

fn gl_error_callback(_: gl.GLenum, _: gl.GLenum, id: gl.GLuint, _: gl.GLenum, _: gl.GLsizei, message: [*:0]const u8, _: ?*anyopaque) callconv(.C) void {
    log.err("GL error {}: {s}", .{ id, message });
}

pub fn main() !void {
    const window1 = w.create_window();
    const context = c.create_context(.OPEN_GL);
    window1.set_current_context(context);
    context.init(window1);

    _ = types.ShaderType.VEC2;

    gl.enable(gl.DEBUG_OUTPUT);
    gl.debugMessageCallback(gl_error_callback, null);

    const vb = b.VertexBuffer.init(context, f32, vertices);
    vb.bind();

    var vertex_shader: u32 = 0;
    vertex_shader = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vertex_shader, 1, &vertex_shader_src.ptr, null);
    gl.compileShader(vertex_shader);

    var fragment_shader: u32 = 0;
    fragment_shader = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(fragment_shader, 1, &fragment_shader_src.ptr, null);
    gl.compileShader(fragment_shader);

    var shader_program: u32 = 0;
    shader_program = gl.createProgram();

    gl.attachShader(shader_program, vertex_shader);
    gl.attachShader(shader_program, fragment_shader);
    gl.linkProgram(shader_program);

    gl.deleteShader(vertex_shader);
    gl.deleteShader(fragment_shader);

    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    while (!window1.should_close()) {
        window1.update();
        context.clear();

        gl.useProgram(shader_program);
        gl.drawArrays(gl.TRIANGLES, 0, 3);

        window1.swap(context);
    }
}
