const std = @import("std");

const engine = @import("engine");

const zm = engine.zm;
const graphics = engine.graphics;
const log = engine.log;
const Window = engine.platform.Window;

const triangle_vertices: []const Vertex = &[_]Vertex{
    .{ .position = .{ 0.0,  0.5, -1 }, .color = .{ 1.0, 0.0, 0.0 } }, // top, red
    .{ .position = .{-0.5, -0.5, -1 }, .color = .{ 0.0, 1.0, 0.0 } }, // bottom left, green
    .{ .position = .{ 0.5, -0.5, -1 }, .color = .{ 0.0, 0.0, 1.0 } }, // bottom right, blue
};

const cube_vertices: []const Vertex = &[_]Vertex{
    // +Z face (red)
    .{ .position = .{  0.5,  0.5,  0.5 }, .color = .{ 1.0, 0.0, 0.0 } },
    .{ .position = .{ -0.5,  0.5,  0.5 }, .color = .{ 1.0, 0.0, 0.0 } },
    .{ .position = .{ -0.5, -0.5,  0.5 }, .color = .{ 1.0, 0.0, 0.0 } },
    .{ .position = .{  0.5, -0.5,  0.5 }, .color = .{ 1.0, 0.0, 0.0 } },

    // +X face (green)
    .{ .position = .{ 0.5,  0.5,  0.5 }, .color = .{ 0.0, 1.0, 0.0 } },
    .{ .position = .{ 0.5, -0.5,  0.5 }, .color = .{ 0.0, 1.0, 0.0 } },
    .{ .position = .{ 0.5, -0.5, -0.5 }, .color = .{ 0.0, 1.0, 0.0 } },
    .{ .position = .{ 0.5,  0.5, -0.5 }, .color = .{ 0.0, 1.0, 0.0 } },

    // +Y face (blue)
    .{ .position = .{  0.5, 0.5,  0.5 }, .color = .{ 0.0, 0.0, 1.0 } },
    .{ .position = .{ 0.5, 0.5, -0.5 }, .color = .{ 0.0, 0.0, 1.0 } },
    .{ .position = .{ -0.5, 0.5, -0.5 }, .color = .{ 0.0, 0.0, 1.0 } },
    .{ .position = .{ -0.5, 0.5,  0.5 }, .color = .{ 0.0, 0.0, 1.0 } },

    // -Z face (yellow)
    .{ .position = .{  0.5, -0.5, -0.5 }, .color = .{ 1.0, 1.0, 0.0 } },
    .{ .position = .{ 0.5,  0.5, -0.5 }, .color = .{ 1.0, 1.0, 0.0 } },
    .{ .position = .{ -0.5, 0.5, -0.5 }, .color = .{ 1.0, 1.0, 0.0 } },
    .{ .position = .{ -0.5, -0.5, -0.5 }, .color = .{ 1.0, 1.0, 0.0 } },

    // -X face (magenta)
    .{ .position = .{ -0.5,  0.5,  0.5 }, .color = .{ 1.0, 0.0, 1.0 } },
    .{ .position = .{ -0.5,  0.5, -0.5 }, .color = .{ 1.0, 0.0, 1.0 } },
    .{ .position = .{ -0.5, -0.5, -0.5 }, .color = .{ 1.0, 0.0, 1.0 } },
    .{ .position = .{ -0.5, -0.5,  0.5 }, .color = .{ 1.0, 0.0, 1.0 } },

    // -Y face (cyan)
    .{ .position = .{ 0.5, -0.5,  0.5 }, .color = .{ 0.0, 1.0, 1.0 } },
    .{ .position = .{ -0.5, -0.5,  0.5 }, .color = .{ 0.0, 1.0, 1.0 } },
    .{ .position = .{ -0.5, -0.5, -0.5 }, .color = .{ 0.0, 1.0, 1.0 } },
    .{ .position = .{ 0.5, -0.5, -0.5 }, .color = .{ 0.0, 1.0, 1.0 } },
};

const cube_indices: []const u32 = &[_]u32{
    // +Z face
    0, 1, 2, 2, 3, 0,
    // +X face
    4, 5, 6, 6, 7, 4,
    // +Y face
    8, 9, 10, 10, 11, 8,
};

const Vertex = packed struct {
    position: zm.Vec3f,
    color: zm.Vec3f,
};

const UniformBufferObject = struct {
    model: zm.Mat4f,
    view: zm.Mat4f,
    proj: zm.Mat4f,
};

const use_debug = false;

pub fn main() !void {
    log.set_level(.DEBUG);

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    var context: graphics.Context = undefined;
    if (args.len != 2) {
        context = graphics.Context.init_none(std.heap.page_allocator, .{ .use_debug = use_debug });
    } else if (std.mem.eql(u8, "vk", args[1])) {
        context = graphics.Context.init_vulkan(std.heap.page_allocator, .{ .use_debug = use_debug });
    } else if (std.mem.eql(u8, "gl", args[1])) {
        context = graphics.Context.init_open_gl(std.heap.page_allocator, .{ .use_debug = use_debug });
    } else {
        context = graphics.Context.init_none(std.heap.page_allocator, .{ .use_debug = use_debug });
    }
    defer context.deinit();

    const window = Window.init(&context, std.heap.page_allocator);
    context.load(&window);

    const target = context.get_target();

    var triangle_buffer = try graphics.VertexBuffer.init(&context, Vertex, triangle_vertices);
    defer triangle_buffer.deinit();

    var cube_vbuffer = try graphics.VertexBuffer.init(&context, Vertex, cube_vertices);
    defer cube_vbuffer.deinit();

    var cube_ibuffer = graphics.IndexBuffer.init(&context, cube_indices);
    defer cube_ibuffer.deinit();

    const vs = try graphics.VertexShader.init(&context, "basic");
    defer vs.deinit();
    const fs = try graphics.FragmentShader.init(&context, "basic");
    defer fs.deinit();

    var mats: UniformBufferObject = .{
        .model = zm.Mat4f.identity().transpose(),
        .view = zm.Mat4f.lookAt(.{10, 10, 10}, .{0, 0, 0}, .{0, 1, 0}).transpose(),
        .proj = zm.Mat4f.perspective(std.math.degreesToRadians(45), 16.0/9.0, 0.1, 100.0).transpose()
    };

    var uniform = graphics.UniformBuffer.init(&context, UniformBufferObject, mats);
    defer uniform.deinit();

    const bindingLayout = graphics.ShaderBindingLayout.init(&context, &.{
        .{.point = 0, .binding_type = .UNIFORM_BUFFER, .stage = .VERTEX_SHADER},
    });
    defer bindingLayout.deinit();

    const bindings = bindingLayout.bind(&context, &.{
        .{.element = .{.UNIFORM_BUFFER = &uniform}, .point = 0},
    });
    defer bindings.deinit();

    const pipeline = try graphics.Pipeline.init(&context, &vs, &fs, &triangle_buffer.get_layout(), &bindings);
    defer pipeline.deinit();

    const cube = graphics.IndexRenderObject.init(&context, &pipeline, &cube_vbuffer, &cube_ibuffer, &bindings).object();

    var last_frame_time: f64 = @floatFromInt(std.time.nanoTimestamp());

    var rot: f32 = 0;
    const speed = 1 * std.math.pi * 2;

    while (!window.should_close()) {
        const current_frame_time: f64 = @floatFromInt(std.time.nanoTimestamp());
        const t: f32 = @as(f32, @floatCast(current_frame_time - last_frame_time)) / 1E9;
        rot += t * speed;
        log.info("Time: {}", .{t});
        mats.proj = zm.Mat4f.perspective(std.math.degreesToRadians(70), @as(f32, @floatFromInt(window.get_size_pixels()[0])) / @as(f32, @floatFromInt(window.get_size_pixels()[1])), 0.1, 100).transpose();
        mats.view = zm.Mat4f.lookAt(.{10.0 * std.math.cos(rot), 10.0, 10.0 * std.math.sin(rot)}, .{0, 0, 0}, .{0, 1, 0}).transpose();
        uniform.set_data(UniformBufferObject, mats);
        window.start_frame();

        target.start()
            .draw(&cube)
            .end();

        window.swap();
        window.update();

        last_frame_time = current_frame_time;
    }
}
