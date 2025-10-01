const std = @import("std");

pub fn build_vulkan_zig(b: *std.Build) *std.Build.Module {
    var env = std.process.getEnvMap(b.allocator) catch unreachable;
    defer env.deinit();

    const vkzig_dep = b.dependency("vulkan", .{
        .registry = @as([]const u8, b.pathFromRoot(b.pathJoin(&.{env.get("VULKAN_HEADERS").?, "share/vulkan/registry/vk.xml"}))),
    });
    return vkzig_dep.module("vulkan-zig");
}
