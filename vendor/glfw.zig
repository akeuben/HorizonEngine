const std = @import("std");

const glfw_files: []const []const u8 = &.{
    "vendor/glfw/src/context.c",
    "vendor/glfw/src/init.c",
    "vendor/glfw/src/input.c",
    "vendor/glfw/src/monitor.c",

    "vendor/glfw/src/null_init.c",
    "vendor/glfw/src/null_joystick.c",
    "vendor/glfw/src/null_monitor.c",
    "vendor/glfw/src/null_window.c",

    "vendor/glfw/src/platform.c",
    "vendor/glfw/src/vulkan.c",
    "vendor/glfw/src/window.c",
};

const glfw_linux_files: []const []const u8 = &.{
    "vendor/glfw/src/x11_init.c",
    "vendor/glfw/src/x11_monitor.c",
    "vendor/glfw/src/x11_window.c",

    "vendor/glfw/src/wl_init.c",
    "vendor/glfw/src/wl_monitor.c",
    "vendor/glfw/src/wl_window.c",

    "vendor/glfw/src/wl_init.c",
    "vendor/glfw/src/wl_monitor.c",
    "vendor/glfw/src/wl_window.c",

    "vendor/glfw/src/xkb_unicode.c",
    "vendor/glfw/src/posix_time.c",
    "vendor/glfw/src/posix_poll.c",
    "vendor/glfw/src/posix_thread.c",
    "vendor/glfw/src/posix_module.c",
    "vendor/glfw/src/glx_context.c",
    "vendor/glfw/src/egl_context.c",
    "vendor/glfw/src/osmesa_context.c",
    "vendor/glfw/src/linux_joystick.c",
};

fn lazy_path_to_string(b: *std.Build, paths: []std.Build.LazyPath) [][]const u8 {
    const p = b.allocator.alloc([]const u8, paths.len) catch @panic("Out of Memory");
    for (paths, 0..) |path, i| {
        p[i] = path.getPath(b);
    }

    return p;
}

pub fn build_glfw(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const protocols: WaylandProtocols = get_wayland_protocols(b, &.{
        .{
            .protocol_path = "xdg-shell.xml",
            .header_name = "xdg-shell-client-protocol.h",
            .implementation_name = "xdg-shell-client-protocol-code.h",
        },
        .{
            .protocol_path = "xdg-decoration-unstable-v1.xml",
            .header_name = "xdg-decoration-unstable-v1-client-protocol.h",
            .implementation_name = "xdg-decoration-unstable-v1-client-protocol-code.h",
        },
        .{
            .protocol_path = "viewporter.xml",
            .header_name = "viewporter-client-protocol.h",
            .implementation_name = "viewporter-client-protocol-code.h",
        },
        .{
            .protocol_path = "relative-pointer-unstable-v1.xml",
            .header_name = "relative-pointer-unstable-v1-client-protocol.h",
            .implementation_name = "relative-pointer-unstable-v1-client-protocol-code.h",
        },
        .{
            .protocol_path = "pointer-constraints-unstable-v1.xml",
            .header_name = "pointer-constraints-unstable-v1-client-protocol.h",
            .implementation_name = "pointer-constraints-unstable-v1-client-protocol-code.h",
        },
        .{
            .protocol_path = "xdg-activation-v1.xml",
            .header_name = "xdg-activation-v1-client-protocol.h",
            .implementation_name = "xdg-activation-v1-client-protocol-code.h",
        },
        .{
            .protocol_path = "fractional-scale-v1.xml",
            .header_name = "fractional-scale-v1-client-protocol.h",
            .implementation_name = "fractional-scale-v1-client-protocol-code.h",
        },
        .{
            .protocol_path = "idle-inhibit-unstable-v1.xml",
            .header_name = "idle-inhibit-unstable-v1-client-protocol.h",
            .implementation_name = "idle-inhibit-unstable-v1-client-protocol-code.h",
        },
        .{
            .protocol_path = "wayland.xml",
            .header_name = "wayland-client-protocol.h",
            .implementation_name = "wayland-client-protocol-code.h",
        },
    });
    const glfw = b.addStaticLibrary(.{
        .name = "glfw",
        .target = target,
        .optimize = optimize,
    });
    glfw.linkLibC();
    glfw.addIncludePath(b.path("vendor/glfw/include"));
    for (protocols.impls) |impl| {
        glfw.addIncludePath(impl);
    }
    for (protocols.headers) |header| {
        glfw.addIncludePath(header);
    }
    glfw.addCSourceFiles(.{ .files = glfw_files });
    glfw.addCSourceFiles(.{ .files = glfw_linux_files });
    glfw.root_module.addCMacro("_GLFW_X11", "1");
    glfw.root_module.addCMacro("_GLFW_WAYLAND", "1");
    glfw.root_module.addCMacro("_GLFW_VULKAN_STATIC", "1");
    glfw.linkSystemLibrary("Xcursor");

    return glfw;
}

const WaylandProtocols = struct {
    headers: []std.Build.LazyPath,
    impls: []std.Build.LazyPath,

    pub fn deinit(self: *WaylandProtocols, b: *std.Build) void {
        b.allocator.free(self.headers);
        b.allocator.free(self.impls);
    }
};

const WaylandProtocolSource = struct {
    protocol_path: []const u8,
    header_name: []const u8,
    implementation_name: []const u8,
};

fn get_wayland_protocols(b: *std.Build, sources: []const WaylandProtocolSource) WaylandProtocols {
    var env = std.process.getEnvMap(b.allocator) catch unreachable;
    defer env.deinit();

    const headers = b.allocator.alloc(std.Build.LazyPath, sources.len) catch unreachable;
    const impls = b.allocator.alloc(std.Build.LazyPath, sources.len) catch unreachable;

    for (sources, 0..) |source, i| {
        const proto_path = b.pathJoin(&.{ b.build_root.path.?, "vendor/glfw/deps/wayland/", source.protocol_path });
        const proto_header = b.addSystemCommand(&[_][]const u8{ "wayland-scanner", "client-header", proto_path });
        const header = proto_header.addOutputFileArg(source.header_name);

        const proto_impl = b.addSystemCommand(&[_][]const u8{ "wayland-scanner", "private-code", proto_path });
        const impl = proto_impl.addOutputFileArg(source.implementation_name);

        headers[i] = header.dirname();
        impls[i] = impl.dirname();
    }

    return .{
        .headers = headers,
        .impls = impls,
    };
}

pub fn get_include_path(b: *std.Build) std.Build.LazyPath {
    return b.path("vendor/glfw/include");
}
