const std = @import("std");

pub fn build_vulkan_zig(b: *std.Build) *std.Build.Module {
    var env = std.process.getEnvMap(b.allocator) catch unreachable;
    defer env.deinit();

    const vkzig_dep = b.dependency("vulkan", .{
        .registry = "vendor/Vulkan-Docs/xml/vk.xml",
    });
    return vkzig_dep.module("vulkan-zig");
}
