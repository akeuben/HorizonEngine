const std = @import("std");

const LogLevel = enum(u8) {
    DEBUG = 0,
    INFO = 1,
    WARNING = 2,
    ERROR = 3,
    FATAL = 4,

    fn as_string(self: LogLevel) []const u8 {
        return switch (self) {
            .DEBUG => "Debug",
            .INFO => "Info",
            .WARNING => "Warn",
            .ERROR => "Error",
            .FATAL => "Fatal",
        };
    }

    fn color(self: LogLevel) []const u8 {
        return switch (self) {
            .DEBUG => "\u{001b}[36m",
            .INFO => "\u{001b}[37m",
            .WARNING => "\u{001b}[33m",
            .ERROR => "\u{001b}[31m",
            .FATAL => "\u{001b}[37;41m",
        };
    }
};

var log_level: LogLevel = .ERROR;
const stdout = std.io.getStdErr().writer();

pub inline fn print(comptime level: LogLevel, format: []const u8, args: anytype) void {
    if (@intFromEnum(level) < @intFromEnum(log_level)) return;
    stdout.print("{s}", .{level.color()}) catch {};
    stdout.print("{s}> ", .{level.as_string()}) catch {};
    stdout.print(format, args) catch {};
    stdout.print("\u{001b}[37;40m\n", .{}) catch {};
}

pub fn debug(comptime format: []const u8, args: anytype) void {
    if (@intFromEnum(LogLevel.DEBUG) < @intFromEnum(log_level)) return;
    stdout.print("{s}", .{LogLevel.DEBUG.color()}) catch {};
    std.debug.print("{s}> ", .{LogLevel.DEBUG.as_string()});
    std.debug.print(format, args);
    std.debug.print("\u{001b}[37;40m\n", .{});
}
pub fn info(comptime format: []const u8, args: anytype) void {
    print(.INFO, format, args);
}
pub fn warn(comptime format: []const u8, args: anytype) void {
    print(.WARNING, format, args);
}
pub fn err(comptime format: []const u8, args: anytype) void {
    print(.ERROR, format, args);
}
pub fn fatal(comptime format: []const u8, args: anytype) void {
    stdout.print("\n", .{}) catch {};
    print(.FATAL, format, args);
    stdout.print("\n", .{}) catch {};
    @panic("A fatal exception occurred.");
}

pub fn set_level(level: LogLevel) void {
    log_level = level;
    info("Updated log level to {s}", .{level.as_string()});
}

pub fn get_level() LogLevel {
    return log_level;
}

pub inline fn not_implemented() void {
    const src = comptime @src();
    warn("The {s} api call has not been implemented for this API", .{src.fn_name});
}
