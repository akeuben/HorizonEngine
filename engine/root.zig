const std = @import("std");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const gl = @cImport({
    @cInclude("GL/gl.h");
});
const context = @import("graphics/context.zig");
const api = @import("graphics/api.zig");

fn error_callback(error_code: c_int, message: [*c]const u8) callconv(.C) void {
    std.debug.print("[ERR] glfw - {}: {s}\n", .{ error_code, message });
}

pub export fn testglfw() u8 {
    api.set_api(.VULKAN) catch {};
    context.swap_buffers() catch {
        std.debug.print("Failed to swap buffers. Unknown API\n", .{});
    };
    _ = glfw.glfwSetErrorCallback(error_callback);
    const result: c_int = glfw.glfwInit();
    if (result != glfw.GLFW_TRUE) {
        std.debug.print("Failed to initialize GLFW! {}\n", .{result});
        return 1;
    }

    const window: ?*glfw.GLFWwindow = glfw.glfwCreateWindow(640, 480, "Engine", null, null);

    glfw.glfwMakeContextCurrent(window);

    while (glfw.glfwWindowShouldClose(window) == 0) {
        gl.glClearColor(0.235, 0.518, 0.91, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
        glfw.glfwPollEvents();
        glfw.glfwSwapBuffers(window);
    }

    glfw.glfwDestroyWindow(window);
    glfw.glfwTerminate();
    return 0;
}
