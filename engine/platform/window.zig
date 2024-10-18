const std = @import("std");
const platform = @import("platform");
const DesktopWindow = @import("desktop/window.zig").DesktopWindow;
const log = @import("../utils/log.zig");
const Context = @import("../graphics/context.zig").Context;

const WindowError = error{UnsupportedPlatform};

pub const Window = union(enum) {
    desktop: DesktopWindow,

    pub fn set_width(self: Window, width: i32) void {
        switch (self) {
            inline else => |case| case.set_width(width),
        }
    }

    pub fn update(self: Window) void {
        switch (self) {
            inline else => |case| case.update(),
        }
    }

    pub fn set_current_context(self: Window, context: Context) void {
        switch (self) {
            inline else => |case| case.set_current_context(context),
        }
    }

    pub fn swap(self: Window, context: Context) void {
        switch (self) {
            inline else => |case| case.swap(context),
        }
    }

    pub fn should_close(self: Window) bool {
        return switch (self) {
            inline else => |case| case.should_close(),
        };
    }

    pub fn get_gl_loader(self: Window, gl_extension: []const u8) ?*anyopaque {
        return switch (self) {
            inline else => |case| case.get_gl_loader(gl_extension),
        };
    }
};

var initialized = false;

pub fn create_window() Window {
    if (!initialized) {
        switch (platform.get_platform()) {
            .LINUX => DesktopWindow.init(),
            .WINDOWS => DesktopWindow.init(),
            else => {
                log.fatal("Attempted to initialize window system on unsupported platform {s}", .{@tagName(platform.get_platform())});
                std.process.exit(1);
            },
        }
        initialized = true;
    }
    return switch (platform.get_platform()) {
        .LINUX => .{ .desktop = DesktopWindow.create_window() },
        .WINDOWS => .{ .desktop = DesktopWindow.create_window() },
        else => {
            log.fatal("Attempted to create a window on an unsupported platform {s}", .{@tagName(platform.get_platform())});
            std.process.exit(1);
        },
    };
}
