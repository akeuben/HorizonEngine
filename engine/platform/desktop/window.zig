const std = @import("std");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const log = @import("../../log/log.zig");

fn error_callback(error_code: c_int, message: [*c]const u8) callconv(.C) void {
    log.debug("glfw - {}: {s}\n", .{ error_code, message });
}

pub const DesktopWindow = struct {
    window: ?*glfw.GLFWwindow,

    pub fn init() void {
        _ = glfw.glfwSetErrorCallback(error_callback);
        if (glfw.glfwInit() != glfw.GLFW_TRUE) {
            log.fatal("Failed to initialize GLFW", .{});
        }
    }

    pub fn set_width(self: DesktopWindow, width: i32) void {
        var current_width: c_int = 0;
        var current_height: c_int = 0;
        glfw.glfwGetWindowSize(self.window, &current_width, &current_height);
        glfw.glfwSetWindowSize(self.window, width, current_height);
    }

    pub fn create_window() DesktopWindow {
        return DesktopWindow{
            .window = glfw.glfwCreateWindow(480, 320, "Engine", null, null),
        };
    }

    pub fn deinit() void {
        glfw.glfwTerminate();
    }

    pub fn update(_: DesktopWindow) void {
        glfw.glfwPollEvents();
    }

    pub fn use_gl(self: DesktopWindow) void {
        glfw.glfwMakeContextCurrent(self.window);
    }

    pub fn swap_buffers_gl(self: DesktopWindow) void {
        glfw.glfwSwapBuffers(self.window);
    }

    pub fn should_close(self: DesktopWindow) bool {
        return glfw.glfwWindowShouldClose(self.window) == glfw.GLFW_TRUE;
    }
};
