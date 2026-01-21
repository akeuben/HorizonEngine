const std = @import("std");

const engine = @import("engine");

const stb = engine.data.stb;

const zm = engine.zm;
const graphics = engine.graphics;
const log = engine.log;
const Window = engine.platform.Window;

const EventNode = engine.event.EventNode;
const init_handler = engine.event.init_handler;
const init_handler_custom = engine.event.init_handler_custom;
const EventResult = engine.event.EventResult;

const cube_vertices: []const Vertex = &[_]Vertex{
    // +Z face (red)
    .{ .position = .{  0.5,  0.5,  0.5 }, .color = .{ 1.0, 0.0, 0.0 }, .uv = .{1.0, 1.0} },
    .{ .position = .{ -0.5,  0.5,  0.5 }, .color = .{ 1.0, 0.0, 0.0 }, .uv = .{0.0, 1.0} },
    .{ .position = .{ -0.5, -0.5,  0.5 }, .color = .{ 1.0, 0.0, 0.0 }, .uv = .{0.0, 0.0} },
    .{ .position = .{  0.5, -0.5,  0.5 }, .color = .{ 1.0, 0.0, 0.0 }, .uv = .{1.0, 0.0} },

    // +X face (green)
    .{ .position = .{ 0.5,  0.5,  0.5 }, .color = .{ 0.0, 1.0, 0.0 }, .uv = .{1.0, 1.0} },
    .{ .position = .{ 0.5, -0.5,  0.5 }, .color = .{ 0.0, 1.0, 0.0 }, .uv = .{1.0, 0.0} },
    .{ .position = .{ 0.5, -0.5, -0.5 }, .color = .{ 0.0, 1.0, 0.0 }, .uv = .{0.0, 0.0} },
    .{ .position = .{ 0.5,  0.5, -0.5 }, .color = .{ 0.0, 1.0, 0.0 }, .uv = .{0.0, 1.0} },

    // +Y face (blue)
    .{ .position = .{  0.5, 0.5,  0.5 }, .color = .{ 0.0, 0.0, 1.0 }, .uv = .{1.0, 1.0} },
    .{ .position = .{ 0.5, 0.5, -0.5 }, .color = .{ 0.0, 0.0, 1.0 }, .uv = .{1.0, 0.0} },
    .{ .position = .{ -0.5, 0.5, -0.5 }, .color = .{ 0.0, 0.0, 1.0 }, .uv = .{0.0, 0.0} },
    .{ .position = .{ -0.5, 0.5,  0.5 }, .color = .{ 0.0, 0.0, 1.0 }, .uv = .{0.0, 1.0} },

    // -Z face (yellow)
    .{ .position = .{  0.5, -0.5, -0.5 }, .color = .{ 1.0, 1.0, 0.0 }, .uv = .{1.0, 0.0} },
    .{ .position = .{ 0.5,  0.5, -0.5 }, .color = .{ 1.0, 1.0, 0.0 }, .uv = .{1.0, 1.0} },
    .{ .position = .{ -0.5, 0.5, -0.5 }, .color = .{ 1.0, 1.0, 0.0 }, .uv = .{0.0, 1.0} },
    .{ .position = .{ -0.5, -0.5, -0.5 }, .color = .{ 1.0, 1.0, 0.0 }, .uv = .{0.0, 0.0} },

    // -X face (magenta)
    .{ .position = .{ -0.5,  0.5,  0.5 }, .color = .{ 1.0, 0.0, 1.0 }, .uv = .{1.0, 1.0} },
    .{ .position = .{ -0.5,  0.5, -0.5 }, .color = .{ 1.0, 0.0, 1.0 }, .uv = .{0.0, 1.0} },
    .{ .position = .{ -0.5, -0.5, -0.5 }, .color = .{ 1.0, 0.0, 1.0 }, .uv = .{0.0, 0.0} },
    .{ .position = .{ -0.5, -0.5,  0.5 }, .color = .{ 1.0, 0.0, 1.0 }, .uv = .{1.0, 0.0} },

    // -Y face (cyan)
    .{ .position = .{ 0.5, -0.5,  0.5 }, .color = .{ 0.0, 1.0, 1.0 }, .uv = .{1.0, 1.0} },
    .{ .position = .{ -0.5, -0.5,  0.5 }, .color = .{ 0.0, 1.0, 1.0 }, .uv = .{0.0, 1.0} },
    .{ .position = .{ -0.5, -0.5, -0.5 }, .color = .{ 0.0, 1.0, 1.0 }, .uv = .{0.0, 0.0} },
    .{ .position = .{ 0.5, -0.5, -0.5 }, .color = .{ 0.0, 1.0, 1.0 }, .uv = .{1.0, 0.0} },
};

const cube_indices: []const u32 = &[_]u32{
    0, 1, 2, 2, 3, 0,
    4, 5, 6, 6, 7, 4,
    8, 9, 10, 10, 11, 8,
    14, 13, 12, 12, 15, 14,
    16, 17, 18, 18, 19, 16,
    20, 21, 22, 22, 23, 20,
};

const Vertex = packed struct {
    position: zm.Vec3f,
    color: zm.Vec3f,
    uv: zm.Vec2f,
};

const UniformBufferObject = struct {
    model: zm.Mat4f,
    view: zm.Mat4f,
    proj: zm.Mat4f,
};

const use_debug = true;

pub fn main_old() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    var allocator = gpa.allocator();
    defer if(gpa.detectLeaks()) {
        log.fatal("Memory Leak detected.", .{});
    };
    
    try engine.data.registry.init(&allocator);
    const reg = engine.data.registry.getRegistry(.{ .namespace = "engine", .id = "test" }).?;

    
    var list = try reg.list();
    while(list.next()) |item| {
        std.log.debug("File exists: {f}", .{item.*});
    }
    const myThing = reg.get(.{ .namespace = "myapp", .id = "a" }, std.json.Value);

    std.log.debug("My Thing: {s}", .{myThing.?.object.get("value").?.string});
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if(gpa.detectLeaks()) {
        std.process.exit(1);
    };
    log.set_level(.DEBUG);

    var val: u32 = 5129;

    var root_event_node = EventNode.init(allocator, &val, &.{
    });

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var context: graphics.Context = undefined;
    if (args.len != 2) {
        context = graphics.Context.init_none(allocator, .{ .use_debug = use_debug });
    } else if (std.mem.eql(u8, "vk", args[1])) {
        context = graphics.Context.init_vulkan(allocator, .{ .use_debug = use_debug });
    } else if (std.mem.eql(u8, "gl", args[1])) {
        context = graphics.Context.init_open_gl(allocator, .{ .use_debug = use_debug });
    } else {
        context = graphics.Context.init_none(allocator, .{ .use_debug = use_debug });
    }
    defer context.deinit();

    const context_node: ?*EventNode = context.get_event_node();
    if(context_node != null) {
        root_event_node.add_child(context_node.?);
    }

    var window = Window.init(&context, allocator);
    context.load(&window);

    root_event_node.add_child(window.get_event_node());

    var target = context.get_target();

    var cube_vbuffer = try graphics.VertexBuffer.init(&context, Vertex, cube_vertices);
    defer cube_vbuffer.deinit();

    const image = try stb.StbImage.load_png("assets/Banana-Single.jpg");
    defer image.deinit();

    const texture = graphics.Texture.init(&context, &image);
    defer texture.deinit();

    var sampler = texture.sampler(.{
        .filter = .LINEAR
    });
    defer sampler.deinit();

    var cube_ibuffer = graphics.IndexBuffer.init(&context, cube_indices);
    defer cube_ibuffer.deinit();

    const vs = try graphics.VertexShader.init(&context, "basic");
    defer vs.deinit();
    const fs = try graphics.FragmentShader.init(&context, "basic");
    defer fs.deinit();

    const a45 = std.math.degreesToRadians(45);
    
    var mats: UniformBufferObject = .{
        .model = zm.Mat4f.identity().transpose(),
        .view = zm.Mat4f.lookAt(.{10, 10, 10}, .{0, 0, 0}, .{0, 1, 0}).transpose(),
        .proj = zm.Mat4f.perspective(a45, 16.0/9.0, 0.1, 100.0).transpose()
    };

    var uniform = graphics.UniformBuffer.init(&context, UniformBufferObject, mats);
    defer uniform.deinit();

    const bindingLayout = graphics.ShaderBindingLayout.init(&context, &.{
        .{.point = 0, .binding_type = .UNIFORM_BUFFER, .stage = .VERTEX_SHADER},
        .{.point = 1, .binding_type = .IMAGE_SAMPLER, .stage = .FRAGMENT_SHADER},
    });
    defer bindingLayout.deinit();

    const bindings = bindingLayout.bind(&context, &.{
        .{.element = &uniform, .point = 0},
        .{.element = &sampler, .point = 1},
    });
    defer bindings.deinit();

    const pipeline = try graphics.Pipeline.init(&context, &vs, &fs, &cube_vbuffer.get_layout(), &bindings);
    defer pipeline.deinit();

    const cube = graphics.IndexRenderObject.init(&context, &pipeline, &cube_vbuffer, &cube_ibuffer, &bindings).object();

    var last_frame_time: f64 = @floatFromInt(std.time.nanoTimestamp());

    var rot: f32 = 0;
    const speed = 0.25 * std.math.pi * 2;

    while (!window.should_close()) {
        const current_frame_time: f64 = @floatFromInt(std.time.nanoTimestamp());
        const t: f32 = @as(f32, @floatCast(current_frame_time - last_frame_time)) / 1E9;
        rot += -t * speed;
        //log.info("FPS: {d:.2}", .{1.0/t});
        mats.proj = zm.Mat4f.perspective(std.math.degreesToRadians(70), @as(f32, @floatFromInt(window.get_size_pixels()[0])) / @as(f32, @floatFromInt(window.get_size_pixels()[1])), 0.1, 100).transpose();
        mats.view = zm.Mat4f.lookAt(.{4.0 * std.math.cos(rot), 0.0, 4.0 * std.math.sin(rot)}, .{0, 0, 0}, .{0, 1, 0}).transpose();
        mats.model = zm.Mat4f.rotation(.{1, 0, 0}, std.math.degreesToRadians(rot * 20)).transpose();
        uniform.set_data(UniformBufferObject, mats);

        window.start_frame();

        target.start()
            .draw(&cube)
            .end();

        window.swap(&context);
        window.update();

        last_frame_time = current_frame_time;
    }
}
