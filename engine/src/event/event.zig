const std = @import("std");
const log = @import("../utils/log.zig");

pub const window = @import("events/WindowEvents.zig");

pub const EventResult = enum(u32) {
    /// The event was handled by a handler, and halted any further event 
    /// propofation
    CONSUMED = 3,
    /// The event was handled by a handler, but will still notify 
    /// other event handlers
    HANDLED = 2,
    /// The event has been seen by a handler, but was ignored.
    IGNORED = 1,
    /// The event has not yet been handled
    DEFAULT = 0,
};

pub const EventHandler = struct {
    type: []const u8,
    handler: *const fn(?*anyopaque, *const anyopaque, EventResult) EventResult,
};

pub fn init_handler(comptime E: anytype, handler: *const fn(?*void, *const E, EventResult) EventResult) EventHandler {
    return EventHandler{
        .type =  @typeName(E),
        .handler = @ptrCast(handler),
    };
}

pub fn init_handler_custom(comptime T: anytype, comptime E: anytype, handler: *const fn(?*T, *const E, EventResult) EventResult) EventHandler {
    return EventHandler{
        .type =  @typeName(E),
        .handler = @ptrCast(handler),
    };
}

pub const EventNode = struct {
    allocator: std.mem.Allocator,
    custom_parameter: ?*anyopaque,
    children: std.ArrayList(*EventNode),
    parent: ?*EventNode,
    handlers: []const EventHandler,

    pub fn init(allocator: std.mem.Allocator, custom_parameter: ?*anyopaque, handlers: []const EventHandler) *EventNode {
        const self = allocator.create(@This()) catch unreachable;
        const handlers_copied = allocator.alloc(EventHandler, handlers.len) catch unreachable;
        @memcpy(handlers_copied, handlers);
        self.allocator = allocator;
        self.custom_parameter = custom_parameter;
        self.children = std.ArrayList(*EventNode).initCapacity(allocator, 0) catch unreachable;
        self.handlers = handlers_copied;
        self.parent = null;

        return self;
    }
    
    pub fn add_child(self: *EventNode, child: *EventNode) void {
        self.children.append(self.allocator, child) catch unreachable;
        child.parent = self;
    }

    pub fn remove_child(self: *EventNode, child: *EventNode) void {
        var to_remove: ?usize = null;

        for(self.children.items, 0..) |item, i| {
            if(item == child) {
                to_remove = i;
            }
        }

        if(to_remove) |remove| {
            _ = self.children.swapRemove(remove);
            child.parent = null;
        }
    }

    pub fn handle_event(self: *const EventNode, comptime E: anytype, event: *const E) EventResult {
        var current_result = EventResult.DEFAULT;

        for(self.handlers) |handler| {
            if(!std.mem.eql(u8, @typeName(E), handler.type)) continue;
            const result = handler.handler(self.custom_parameter, event, current_result);

            if(@intFromEnum(result) > @intFromEnum(current_result)) {
                current_result = result;
            }

            if(current_result == .CONSUMED) {
                return current_result;
            }
        }

        for(self.children.items) |child| {
            const result = child.handle_event(E, event);

            if(@intFromEnum(result) > @intFromEnum(current_result)) {
                current_result = result;
            }

            if(current_result == .CONSUMED) {
                return current_result;
            }
        }

        return current_result;
    }

    pub fn handle_event_at_root(self: *const EventNode, comptime E: anytype, event: *const E) EventResult {
        if(self.parent != null) {
            return self.parent.?.handle_event_at_root(E, event);
        }

        return self.handle_event(E, event);
    }

    pub fn deinit(self: *EventNode) void {
        log.debug("Deinit event node with {} handlers and {} children", .{self.handlers.len, self.children.items.len});
        self.allocator.free(self.handlers);
        self.children.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};
