const std = @import("std");
const platform = @import("platform");
const DesktopWindow = @import("desktop/window.zig").DesktopWindow;
const log = @import("../log/log.zig");
const api = @import("../graphics/api.zig");

const WindowError = error{ UnsupportedPlatform, IncorrectAPI };

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

    pub fn use_gl(self: Window) !void {
        if (api.get_api() != api.API.OPEN_GL) {
            return WindowError.IncorrectAPI;
        }
        switch (self) {
            inline else => |case| case.use_gl(),
        }
    }

    pub fn swap_buffers_gl(self: Window) !void {
        if (api.get_api() != api.API.OPEN_GL) {
            return WindowError.IncorrectAPI;
        }
        switch (self) {
            inline else => |case| case.swap_buffers_gl(),
        }
    }

    pub fn should_close(self: Window) bool {
        return switch (self) {
            inline else => |case| case.should_close(),
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
