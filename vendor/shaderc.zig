const std = @import("std");

pub fn build_shaderc(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const shaderc_dep = b.dependency("shaderc_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const c = b.createModule(.{
        .root_source_file = .{
            .cwd_relative = b.build_root.join(b.allocator, &.{
                "vendor",
                "shaderc",
                "raw.zig",
            }) catch unreachable,
        },
        .target = b.graph.host,
        .optimize = .Debug,
    });
    c.linkLibrary(shaderc_dep.artifact("shaderc"));

    const shaderc = b.createModule(.{
        .root_source_file = .{
            .cwd_relative = b.build_root.join(b.allocator, &.{
                "vendor",
                "shaderc",
                "shaderc.zig",
            }) catch unreachable,
        },
        .target = target,
        .optimize = optimize,
    });
    shaderc.addImport("c", c);

    return shaderc;
}
