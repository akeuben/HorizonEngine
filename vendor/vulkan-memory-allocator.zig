const std = @import("std");

pub fn build_vma(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    var vma = b.addModule("vma", .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    const cpp_source_dir = b.addWriteFiles();
    const cpp_source = cpp_source_dir.add("vma_impl.cpp",
        \\#define VMA_IMPLEMENTATION
        \\#define VMA_STATIC_VULKAN_FUNCTIONS 0
        \\#define VMA_DYNAMIC_VULKAN_FUNCTIONS 1
        \\#define VMA_VULKAN_VERSION 1000000
        \\#include <vk_mem_alloc.h>
    );
    vma.linkSystemLibrary("vulkan", .{
        .preferred_link_mode = .dynamic,
        .needed = true,
    });
    vma.addIncludePath(b.path("vendor/VulkanMemoryAllocator/include"));
    vma.addCSourceFile(.{ .file = cpp_source });

    return vma;
}

pub fn get_include_path(b: *std.Build) std.Build.LazyPath {
    return b.path("vendor/VulkanMemoryAllocator/include");
}
