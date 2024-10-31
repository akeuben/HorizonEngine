const std = @import("std");

pub fn build_vma(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    var vma = b.addStaticLibrary(.{
        .name = "vma",
        .target = target,
        .root_source_file = b.path("lib/vma/src/vma.zig"),
        .optimize = optimize,
    });
    vma.linkSystemLibrary("vulkan");
    vma.addIncludePath(b.path("vendor/VulkanMemoryAllocator/include"));
    vma.addCSourceFile(.{ .file = b.path("lib/vma/src/vma_impl.cpp") });
    vma.linkLibCpp();

    return vma;
}

pub fn get_include_path(b: *std.Build) std.Build.LazyPath {
    return b.path("vendor/VulkanMemoryAllocator/include");
}
