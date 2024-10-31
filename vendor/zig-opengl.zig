const std = @import("std");

const ZigOpenGLOptions = struct { gl_version: []const u8, gl_extensions: []const []const u8 };

pub fn build_zig_opengl(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, options: ZigOpenGLOptions) *std.Build.Step.Compile {
    const gen_opengl_bindings = b.addSystemCommand(&[_][]const u8{ "dotnet", "run", "--project", "vendor/zig-opengl" });

    gen_opengl_bindings.addArg("vendor/zig-opengl/OpenGL-Registry/xml/gl.xml");
    const gl_output = gen_opengl_bindings.addOutputFileArg("gl.zig");
    gen_opengl_bindings.addArg(options.gl_version);
    gen_opengl_bindings.addArgs(options.gl_extensions);

    const zig_opengl = b.addStaticLibrary(.{
        .name = "zig-opengl",
        .root_source_file = gl_output,
        .target = target,
        .optimize = optimize,
    });

    return zig_opengl;
}
