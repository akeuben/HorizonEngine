const std = @import("std");
const vendor = @import("../vendor/build.zig");

const GL_VERSION = "GL_VERSION_4_3";
const GL_EXTENSIONS: []const []const u8 = &.{"GL_ARB_gl_spirv"};

pub fn build_engine(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    // Options
    const options = b.addOptions();
    options.addOption(std.Target.Os.Tag, "os", target.result.os.tag);

    // Dependencies
    const zm = b.dependency("zm", .{});
    const vma = vendor.vma.build_vma(b, target, optimize);
    const glfw = vendor.glfw.build_glfw(b, target, optimize);
    const vulkan_zig = vendor.vulkan_zig.build_vulkan_zig(b);
    const shaderc = vendor.shaderc.build_shaderc(b, target, optimize);
    const zig_opengl = vendor.zig_opengl.build_zig_opengl(b, target, optimize, .{
        .gl_version = GL_VERSION,
        .gl_extensions = GL_EXTENSIONS,
    });
    const stb = vendor.stb.build_stb(b, target, optimize);

    // Library
    var lib = b.addStaticLibrary(.{
        .name = "engine",
        .root_source_file = b.path("engine/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    if(b.lazyDependency("x11_headers", .{
        .target = target,
        .optimize = optimize,
    })) |x11_headers| {
        lib.linkLibrary(x11_headers.artifact("x11-headers"));
    }

    // Link C Libraries
    lib.addIncludePath(vendor.glfw.get_include_path(b));
    lib.linkLibrary(glfw);
    lib.addIncludePath(vendor.vma.get_include_path(b));
    lib.linkLibrary(vma);
    lib.addIncludePath(vendor.stb.get_include_path(b));
    lib.linkLibrary(stb);

    // Link Zig Libraries
    lib.root_module.addImport("zm", zm.module("zm"));
    lib.root_module.addImport("vulkan", vulkan_zig);
    lib.root_module.addImport("gl", zig_opengl.root_module);
    lib.root_module.addImport("shaderc", shaderc);

    // Link Options
    lib.root_module.addOptions("platform", options);

    return lib;
}
