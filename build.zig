const std = @import("std");
const Platform = enum { LINUX, NONE };

fn get_vkzig_bindings(b: *std.Build, env: std.process.EnvMap) *std.Build.Module {
    const vkzig_dep = b.dependency("vulkan_zig", .{
        .registry = @as([]const u8, b.pathFromRoot(env.get("VULKAN_REGISTRY").?)),
    });
    const vkzig_bindings = vkzig_dep.module("vulkan-zig");
    return vkzig_bindings;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glfw_files: []const []const u8 = &.{
        "lib/glfw/src/context.c",
        "lib/glfw/src/init.c",
        "lib/glfw/src/input.c",
        "lib/glfw/src/monitor.c",

        "lib/glfw/src/null_init.c",
        "lib/glfw/src/null_joystick.c",
        "lib/glfw/src/null_monitor.c",
        "lib/glfw/src/null_window.c",

        "lib/glfw/src/platform.c",
        "lib/glfw/src/vulkan.c",
        "lib/glfw/src/window.c",
    };

    const glfw_linux_files: []const []const u8 = &.{
        "lib/glfw/src/x11_init.c",
        "lib/glfw/src/x11_monitor.c",
        "lib/glfw/src/x11_window.c",

        "lib/glfw/src/wl_init.c",
        "lib/glfw/src/wl_monitor.c",
        "lib/glfw/src/wl_window.c",

        "lib/glfw/src/xkb_unicode.c",
        "lib/glfw/src/posix_time.c",
        "lib/glfw/src/posix_poll.c",
        "lib/glfw/src/posix_thread.c",
        "lib/glfw/src/posix_module.c",
        "lib/glfw/src/glx_context.c",
        "lib/glfw/src/egl_context.c",
        "lib/glfw/src/osmesa_context.c",
        "lib/glfw/src/linux_joystick.c",
    };

    const allocator = std.heap.page_allocator;
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    const vkzig_bindings = get_vkzig_bindings(b, env);
    const zgl = b.dependency("zgl", .{
        .target = target,
        .optimize = optimize,
    });

    const tool = b.addExecutable(.{
        .name = "generate_struct",
        .root_source_file = b.path("build/generate/platform.zig"),
        .target = b.host,
    });

    const tool_step = b.addRunArtifact(tool);
    tool_step.addArg(@tagName(target.result.os.tag));
    const output = tool_step.addOutputFileArg("platform.zig");

    const lib = b.addStaticLibrary(.{
        .name = "engine",
        .root_source_file = b.path("engine/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    lib.addIncludePath(b.path("lib/glfw/include"));
    lib.addCSourceFiles(.{ .files = glfw_files });
    lib.addCSourceFiles(.{ .files = glfw_linux_files });
    lib.defineCMacro("_GLFW_X11", "1");
    lib.root_module.addAnonymousImport("platform", .{ .root_source_file = output });

    lib.root_module.addImport("vulkan", vkzig_bindings);
    lib.root_module.addImport("zgl", zgl.module("zgl"));
    lib.linkSystemLibrary("Xcursor");
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("example/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("engine", &lib.root_module);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
