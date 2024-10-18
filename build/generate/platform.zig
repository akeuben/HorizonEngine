const std = @import("std");

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    const platform_name: []u8 = try std.heap.page_allocator.alloc(u8, args[1].len);
    defer std.heap.page_allocator.free(platform_name);
    _ = std.ascii.upperString(platform_name, args[1]);

    const output_file_path = args[2];

    var output_file = std.fs.cwd().createFile(output_file_path, .{}) catch |err| {
        std.debug.print("unable to open '{s}': {s}\n", .{ output_file_path, @errorName(err) });
        std.process.exit(1);
    };
    defer output_file.close();

    try output_file.writeAll(
        \\pub const Platform = enum {
        \\    LINUX, WINDOWS, NONE
        \\};
        \\const platform = .
    );

    try output_file.writeAll(platform_name);
    try output_file.writeAll(
        \\;
        \\
        \\pub fn get_platform() Platform {
        \\    return platform;
        \\}
    );
    return std.process.cleanExit();
}
