const std = @import("std");
const Scanner = @import("wayland").Scanner;

pub fn build_wayland(b: *std.Build) *std.Build.Module {
    const scanner = Scanner.create(b, .{});

    const wayland = b.createModule(.{ .root_source_file = scanner.result });

    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");

    scanner.generate("wl_seat", 4);

    return wayland;
}
