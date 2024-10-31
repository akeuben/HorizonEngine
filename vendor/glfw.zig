const std = @import("std");

const glfw_files: []const []const u8 = &.{
    "vendor/glfw/src/context.c",
    "vendor/glfw/src/init.c",
    "vendor/glfw/src/input.c",
    "vendor/glfw/src/monitor.c",

    "vendor/glfw/src/null_init.c",
    "vendor/glfw/src/null_joystick.c",
    "vendor/glfw/src/null_monitor.c",
    "vendor/glfw/src/null_window.c",

    "vendor/glfw/src/platform.c",
    "vendor/glfw/src/vulkan.c",
    "vendor/glfw/src/window.c",
};

const glfw_linux_files: []const []const u8 = &.{
    "vendor/glfw/src/x11_init.c",
    "vendor/glfw/src/x11_monitor.c",
    "vendor/glfw/src/x11_window.c",

    "vendor/glfw/src/wl_init.c",
    "vendor/glfw/src/wl_monitor.c",
    "vendor/glfw/src/wl_window.c",

    "vendor/glfw/src/xkb_unicode.c",
    "vendor/glfw/src/posix_time.c",
    "vendor/glfw/src/posix_poll.c",
    "vendor/glfw/src/posix_thread.c",
    "vendor/glfw/src/posix_module.c",
    "vendor/glfw/src/glx_context.c",
    "vendor/glfw/src/egl_context.c",
    "vendor/glfw/src/osmesa_context.c",
    "vendor/glfw/src/linux_joystick.c",
};

pub fn build_glfw(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const glfw = b.addStaticLibrary(.{
        .name = "glfw",
        .target = target,
        .optimize = optimize,
    });
    glfw.linkLibC();
    glfw.addIncludePath(b.path("vendor/glfw/include"));
    glfw.addCSourceFiles(.{ .files = glfw_files });
    glfw.addCSourceFiles(.{ .files = glfw_linux_files });
    glfw.defineCMacro("_GLFW_X11", "1");
    glfw.linkSystemLibrary("Xcursor");

    return glfw;
}

pub fn get_include_path(b: *std.Build) std.Build.LazyPath {
    return b.path("vendor/glfw/include");
}
