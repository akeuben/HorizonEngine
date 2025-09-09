const Context = @import("context.zig").OpenGLContext;
const Image = @import("../texture.zig").Image;
const gl = @import("gl");
const TextureSampler = @import("../texture.zig").TextureSampler;
const SamplerOptions = @import("../texture.zig").SamplerOptions;
const TextureFilter = @import("../texture.zig").TextureFilter;
const log = @import("../../utils/log.zig");

pub const OpenGLTexture = struct {
    gl_texture: u32,

    pub fn init(_: *const Context, image: *const Image) OpenGLTexture {
        var self: OpenGLTexture = undefined;
        gl.genTextures(1, &self.gl_texture);
        self.set_data(image);

        return self;
    }

    pub fn set_data(self: *const OpenGLTexture, image: *const Image) void {
        gl.bindTexture(gl.TEXTURE_2D, self.gl_texture);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.SRGB8_ALPHA8, image.width, image.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, image.pixels);
        gl.generateMipmap(gl.TEXTURE_2D);
        log.debug("Set texture data", .{});
    }

    pub fn sampler(self: *const OpenGLTexture, options: SamplerOptions) TextureSampler {
        return TextureSampler{
            .OPEN_GL = OpenGLTextureSampler.init(self, options),
        };
    }

    pub fn deinit(self: *const OpenGLTexture) void {
        gl.deleteTextures(1, @ptrCast(&self.gl_texture));
    }
};

fn filter_to_gl_enum(filter: TextureFilter) c_int {
    return switch(filter) {
        .LINEAR => gl.LINEAR,
        .POINT => gl.NEAREST,
    };
}

pub const OpenGLTextureSampler = struct {
    texture: u32,
    options: SamplerOptions,

    fn init(texture: *const OpenGLTexture, options: SamplerOptions) OpenGLTextureSampler {
        return OpenGLTextureSampler{
            .texture = texture.gl_texture,
            .options = options,
        };
    }

    pub fn bind(self: *const OpenGLTextureSampler) void {
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter_to_gl_enum(self.options.filter));
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter_to_gl_enum(self.options.filter));
        gl.bindTexture(gl.TEXTURE_2D, self.texture);
    }

    pub fn deinit(_: *const OpenGLTextureSampler) void {
        
    }
};
