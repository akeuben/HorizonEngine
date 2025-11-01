const std = @import("std");
const runtime = @import("runtime/builder.zig");

pub fn build(b: *std.Build) !void {
    const arch: std.Target.Cpu.Arch = .x86_64;
    const tag: std.Target.Os.Tag = .linux;
    const abi: std.Target.Abi = .gnu;
    const os: std.Target.Os = .{ .tag = tag, .version_range = .default(arch, tag, abi) };
    const cpu: std.Target.Cpu = .baseline(arch, os);
    const target = b.resolveTargetQuery(.{
        .abi = .gnu, .cpu_arch = .x86_64, .os_tag = .linux,
        .dynamic_linker = .standard(cpu, os, abi),
    });
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
