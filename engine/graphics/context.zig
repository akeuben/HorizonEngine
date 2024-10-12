const opengl = @import("opengl/context.zig");
const vulkan = @import("vulkan/context.zig");
const api = @import("api.zig");

pub fn swap_buffers() !void {
    switch (api.get_api()) {
        .NONE => return api.APIError.API_NOT_IMPLEMENTED,
        .VULKAN => return vulkan.swap_buffers(),
        .OPEN_GL => return opengl.swap_buffers(),
    }
}
