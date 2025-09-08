const std = @import("std");
const log = @import("../utils/log.zig");
const stb = @cImport({
    @cInclude("stb_image.h");
});
const Image = @import("../graphics/root.zig").Image;

const DataError = @import("root.zig").DataError;

pub const StbImage = struct {
    pub fn load_png(filename: []const u8) DataError!Image {
        var width: i32 = 0;
        var height: i32 = 0; 
        var channels: i32 = 0;

        stb.stbi_set_flip_vertically_on_load(1);

        const pixels = stb.stbi_load(filename.ptr, &width, &height, &channels, stb.STBI_rgb_alpha);

        if(pixels == null) {
            log.err("Failed to load image file {s}", .{filename});
            return DataError.LoadError;
        }

        return Image{
            .width = width,
            .height = height,
            .channels = channels,
            .pixels = pixels,
            .deinitFn = deinit_stb_image,
        };
    }

    fn deinit_stb_image(self: *const Image) void {
        stb.stbi_image_free(self.pixels);
    }
};
