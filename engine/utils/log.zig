const std = @import("std");

const LogLevel = enum(u8) {
    DEBUG = 0,
    INFO = 1,
    WARNING = 2,
    ERROR = 3,
    FATAL = 4,

    fn as_string(self: LogLevel) []const u8 {
        return switch (self) {
            .DEBUG => "DEBUG",
            .INFO => "INFO",
            .WARNING => "WARN",
            .ERROR => "ERR",
            .FATAL => "FATAL",
        };
    }
};

var log_level: LogLevel = .FATAL;
const stdout = std.io.getStdErr().writer();

pub inline fn print(comptime level: LogLevel, format: []const u8, args: anytype) void {
    stdout.print("[{s}] ", .{level.as_string()}) catch {
        std.process.exit(1);
    };
    stdout.print(format, args) catch {
        std.process.exit(1);
    };
    stdout.print(".\n", .{}) catch {
        std.process.exit(1);
    };
}

pub inline fn debug(comptime format: []const u8, args: anytype) void {
    print(.DEBUG, format, args);
}
pub inline fn info(comptime format: []const u8, args: anytype) void {
    print(.INFO, format, args);
}
pub inline fn warn(comptime format: []const u8, args: anytype) void {
    print(.WARN, format, args);
}
pub inline fn err(comptime format: []const u8, args: anytype) void {
    print(.ERROR, format, args);
}
pub inline fn fatal(comptime format: []const u8, args: anytype) void {
    print(.FATAL, format, args);
}

pub fn set_level(level: LogLevel) void {
    log_level = level;
    info("Updated log level to {s}", .{level.as_string()});
}

pub fn get_level() LogLevel {
    return log_level;
}
