const std = @import("std");

pub fn build_stb(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    var stb = b.addModule("stb", .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const c_source_dir = b.addWriteFiles();
    const c_source = c_source_dir.add("stb_impl.c", 
        \\#define STB_IMAGE_IMPLEMENTATION
        \\#include "stb_image.h"
    );
    stb.addIncludePath(b.path("vendor/stb"));
    stb.addCSourceFile(.{ .file = c_source });

    return stb;
}

pub fn get_include_path(b: *std.Build) std.Build.LazyPath {
    return b.path("vendor/stb");
}
