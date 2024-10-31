const std = @import("std");
const engine = @import("../engine/build.zig");

pub fn build_runtime(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*std.Build.Step.Compile {
    const engine_obj = engine.build_engine(b, target, optimize);

    const exe = b.addExecutable(.{
        .name = "engine_runtime",
        .root_source_file = b.path("runtime/src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("engine", &engine_obj.root_module);

    return exe;
}
