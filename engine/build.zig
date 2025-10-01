const std = @import("std");
const vendor = @import("../vendor/build.zig");
const Scanner = @import("wayland").Scanner;

const GL_VERSION = "GL_VERSION_4_3";
const GL_EXTENSIONS: []const []const u8 = &.{"GL_ARB_gl_spirv"};

pub fn build_engine(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    // Options
    const options = b.addOptions();
    options.addOption(std.Target.Os.Tag, "os", target.result.os.tag);

    // Dependencies
    const zm = b.dependency("zm", .{});
    const vma = vendor.vma.build_vma(b, target, optimize);
    const vulkan_zig = vendor.vulkan_zig.build_vulkan_zig(b);
    const shaderc = vendor.shaderc.build_shaderc(b, target, optimize);
    const zig_opengl = vendor.zig_opengl.build_zig_opengl(b, target, optimize, .{
        .gl_version = GL_VERSION,
        .gl_extensions = GL_EXTENSIONS,
    });
    const stb = vendor.stb.build_stb(b, target, optimize);

    // Library
    var lib = b.addModule("engine", .{
        .root_source_file = b.path("engine/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{.name = "zm", .module = zm.module("zm") },
            .{ .name = "vulkan", .module =  vulkan_zig },
            .{ .name = "gl", .module =  zig_opengl },
            .{ .name = "shaderc", .module =  shaderc },
            .{ .name = "vma", .module =  vma },
            .{ .name = "stb", .module =  stb },
        },
    });

    if(b.lazyDependency("X11_zig", .{
        .target = target,
        .optimize = optimize,
    })) |x11_headers| {
        lib.linkLibrary(x11_headers.artifact("X11"));
    }

    // Link C Libraries
    lib.addIncludePath(vendor.vma.get_include_path(b));
    lib.addIncludePath(vendor.stb.get_include_path(b));

    var env = std.process.getEnvMap(b.allocator) catch unreachable;
    defer env.deinit();

    const vulkan_include = std.Build.LazyPath{.cwd_relative = b.pathJoin(&.{env.get("VULKAN_HEADERS").?, "include"})};

    lib.addSystemIncludePath(vulkan_include);

    // Link Zig Libraries

    // Link Options
    lib.addOptions("platform", options);

    return lib;
}
