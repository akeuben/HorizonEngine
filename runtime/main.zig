const std = @import("std");

const engine = @import("engine");

const w = engine.platform.window;
const types = engine.graphics.types;
const c = engine.graphics.context;
const b = engine.graphics.buffer;
const o = engine.graphics.object;
const s = engine.graphics.shader;
const log = engine.log;
const gl = engine.gl;
const zm = engine.zm;

const triangle_vertices: []const Vertex = &[_]Vertex{
    .{ .position = .{ -0.75, -0.75 }, .color = .{ 1.0, 1.0, 1.0 } },
    .{ .position = .{ -0.25, -0.75 }, .color = .{ 1.0, 1.0, 1.0 } },
    .{ .position = .{ -0.5, -0.25 }, .color = .{ 1.0, 1.0, 1.0 } },
};

const square_vertices: []const Vertex = &[_]Vertex{
    .{ .position = .{ 0.25, 0.25 }, .color = .{ 0.0, 1.0, 1.0 } },
    .{ .position = .{ 0.25, 0.75 }, .color = .{ 0.0, 1.0, 1.0 } },
    .{ .position = .{ 0.75, 0.25 }, .color = .{ 0.0, 1.0, 1.0 } },
    .{ .position = .{ 0.75, 0.25 }, .color = .{ 0.0, 1.0, 1.0 } },
    .{ .position = .{ 0.25, 0.75 }, .color = .{ 0.0, 1.0, 1.0 } },
    .{ .position = .{ 0.75, 0.75 }, .color = .{ 0.0, 1.0, 1.0 } },
};

const vertex_shader_src: []const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec2 aPos;
    \\layout (location = 1) in vec3 aColor;
    \\out vec3 bColor;
    \\
    \\void main() {
    \\  gl_Position = vec4(aPos, 0.0, 1.0);
    \\  bColor = aColor;
    \\}
;

const fragment_shader_src: []const u8 =
    \\#version 330 core
    \\in vec3 bColor;
    \\out vec4 FragColor;
    \\
    \\void main() {
    \\  FragColor = vec4(bColor, 1.0f);
    \\}
;

const Vertex = extern struct {
    position: zm.Vec2f,
    color: zm.Vec3f,
};

pub fn main() !void {
    const window = w.create_window();
    const context = c.Context.init_open_gl(&window);

    const vs = try s.VertexShader.init(&context, vertex_shader_src);
    const fs = try s.FragmentShader.init(&context, fragment_shader_src);
    const pipeline = try s.Pipeline.init(&context, &vs, &fs);

    const triangle_buffer = try b.VertexBuffer.init(&context, Vertex, triangle_vertices);
    const triangle = o.RenderObject.init(&context, &triangle_buffer, &pipeline);

    const square_buffer = try b.VertexBuffer.init(&context, Vertex, square_vertices);
    const square = o.RenderObject.init(&context, &square_buffer, &pipeline);

    vs.deinit();
    fs.deinit();

    while (!window.should_close()) {
        window.update();

        context.clear();

        triangle.render();
        square.render();

        window.swap(context);
    }
}
