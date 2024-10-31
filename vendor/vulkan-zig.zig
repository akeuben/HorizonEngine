const std = @import("std");

pub fn build_vulkan_zig(b: *std.Build) *std.Build.Module {
    var env = std.process.getEnvMap(b.allocator) catch unreachable;
    defer env.deinit();

    const vkzig_dep = b.dependency("vulkan_zig", .{
        .registry = @as([]const u8, b.pathFromRoot(env.get("VULKAN_REGISTRY").?)),
    });
    return vkzig_dep.module("vulkan-zig");
}
