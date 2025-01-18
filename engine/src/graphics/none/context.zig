const std = @import("std");
const log = @import("../../utils/log.zig");
const Window = @import("../../platform/window.zig").Window;
const NoneVertexBuffer = @import("buffer.zig").NoneVertexBuffer;
const NonePipeline = @import("shader.zig").NonePipeline;
const NoneRenderTarget = @import("target.zig").NoneRenderTarget;
const ContextCreationOptions = @import("../context.zig").ContextCreationOptions;

pub const NoneContext = struct {
    allocator: std.mem.Allocator,
    target: NoneRenderTarget,

    creation_options: ContextCreationOptions,

    pub fn init(allocator: std.mem.Allocator, options: ContextCreationOptions) *NoneContext {
        var ctx = allocator.create(NoneContext) catch unreachable;
        ctx.target = .{};
        ctx.creation_options = options;

        return ctx;
    }

    pub fn get_target(self: *NoneContext) NoneRenderTarget {
        return self.target;
    }

    pub fn notify_resized(_: *NoneContext) void {}

    pub fn load(_: *NoneContext, _: *const Window) void {}

    pub fn deinit(self: *NoneContext) void {
        self.allocator.destroy(self);
    }
};
