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

const Vertex = extern struct {
    position: zm.Vec2f,
    color: zm.Vec3f,
};

pub fn main() !void {
    log.set_level(.DEBUG);
    var context = c.Context.init_open_gl();
    defer context.deinit();

    const window = w.create_window(&context);
    context.load(&window);

    const pipeline = try s.Pipeline.init_inline(&context, "basic");

    const triangle_buffer = try b.VertexBuffer.init(&context, Vertex, triangle_vertices);
    const triangle = o.RenderObject.init(&context, &triangle_buffer, &pipeline);

    const square_buffer = try b.VertexBuffer.init(&context, Vertex, square_vertices);
    const square = o.RenderObject.init(&context, &square_buffer, &pipeline);

    while (!window.should_close()) {
        window.update();

        context.clear();

        triangle.render();
        square.render();

        window.swap(context);
    }
}
