pub const Application = struct {
    pub const Hooks = struct {
        pre_update: ?*const fn (self: *Application) void,
        post_update: ?*const fn (self: *Application) void,
        pre_render: ?*const fn () void,
        post_render: ?*const fn () void,
    };

    hooks: Hooks,
};
