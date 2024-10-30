const std = @import("std");

const engine = @import("engine");

const w = engine.platform.window;
const types = engine.graphics.types;
const c = engine.graphics.context;
const b = engine.graphics.buffer;
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

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    var context: c.Context = undefined;
    if (args.len != 2) {
        context = c.Context.init_none();
    } else if (std.mem.eql(u8, "vk", args[1])) {
        context = c.Context.init_vulkan();
    } else if (std.mem.eql(u8, "gl", args[1])) {
        context = c.Context.init_open_gl();
    } else {
        context = c.Context.init_none();
    }

    const window = w.create_window(&context, std.heap.page_allocator);
    context.load(&window);

    const target = context.get_target();

    const triangle_buffer = try b.VertexBuffer.init(&context, Vertex, triangle_vertices);
    const triangle_pipeline = try s.Pipeline.init_inline(&context, "basic", &triangle_buffer.get_layout(), &target);

    while (!window.should_close()) {
        window.start_frame(&context);
        target.start(&context);
        target.render(&context, &triangle_pipeline, &triangle_buffer);
        target.end(&context);
        target.submit(&context);

        window.swap(&context);
        window.update();
    }

    triangle_pipeline.deinit();
    context.deinit();
}
