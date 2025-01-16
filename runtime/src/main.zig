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
    .{ .position = .{ -0.75, -0.75 }, .color = .{ 1.0, 0.0, 0.0 } },
    .{ .position = .{ -0.25, -0.75 }, .color = .{ 0.0, 1.0, 0.0 } },
    .{ .position = .{ -0.5, -0.25 }, .color = .{ 0.0, 0.0, 1.0 } },
};

const rectangle_vertices: []const Vertex = &[_]Vertex{
    .{ .position = .{ 0.25, 0.25 }, .color = .{ 0, 1, 1 } },
    .{ .position = .{ 0.25, 0.75 }, .color = .{ 1, 0, 1 } },
    .{ .position = .{ 0.75, 0.25 }, .color = .{ 0, 1, 1 } },
    .{ .position = .{ 0.75, 0.75 }, .color = .{ 1, 0, 0 } },
};

const renctangle_indices: []const u32 = &[_]u32{ 0, 1, 2, 2, 1, 3 };

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
        context = c.Context.init_none(std.heap.page_allocator);
    } else if (std.mem.eql(u8, "vk", args[1])) {
        context = c.Context.init_vulkan(std.heap.page_allocator);
    } else if (std.mem.eql(u8, "gl", args[1])) {
        context = c.Context.init_open_gl(std.heap.page_allocator);
    } else {
        context = c.Context.init_none(std.heap.page_allocator);
    }
    defer context.deinit();

    const window = w.create_window(&context, std.heap.page_allocator);
    context.load(&window);

    const target = context.get_target();

    const triangle_buffer = try b.VertexBuffer.init(&context, Vertex, triangle_vertices);
    defer triangle_buffer.deinit();
    const rectangle_buffer = try b.VertexBuffer.init(&context, Vertex, rectangle_vertices);
    defer rectangle_buffer.deinit();
    const rectangle_index_buffer = try b.IndexBuffer.init(&context, renctangle_indices);
    defer rectangle_index_buffer.deinit();

    const pipeline = try s.Pipeline.init_inline(&context, "basic", &triangle_buffer.get_layout(), &target);
    defer pipeline.deinit();

    var triangle = o.VertexRenderObject.init(&context, &pipeline, &triangle_buffer).object();
    const rectangle = o.IndexRenderObject.init(&context, &pipeline, &rectangle_buffer, &rectangle_index_buffer).object();

    while (!window.should_close()) {
        window.start_frame();
        target.start();
        target.render(&triangle);
        target.render(&rectangle);
        target.end();
        target.submit();

        window.swap();
        window.update();
    }
}
