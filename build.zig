const std = @import("std");
const runtime = @import("runtime/build.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const runtime_obj = try runtime.build_runtime(b, target, optimize);

    b.installArtifact(runtime_obj);

    const run_cmd = b.addRunArtifact(runtime_obj);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
