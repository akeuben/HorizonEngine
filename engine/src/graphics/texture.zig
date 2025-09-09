const context = @import("context.zig");
const log = @import("../utils/log.zig");

const vulkan = @import("vulkan/texture.zig");
const opengl = @import("opengl/texture.zig");

pub const TextureFilter = enum {
    POINT,
    LINEAR,
};

pub const SamplerOptions = struct {
    filter: TextureFilter,
};

pub const Image = struct {
    width: i32,
    height: i32,
    channels: i32,
    pixels: *u8,
    deinitFn: *const fn (*const Image) void,

    pub fn deinit(self: *const Image) void {
        self.deinitFn(self);
    }
};

pub const Texture = union(context.API) {
    OPEN_GL: opengl.OpenGLTexture,
    VULKAN: vulkan.VulkanTexture,
    NONE: void,

    pub fn init(ctx: *const context.Context, image: *const Image) Texture {
        return switch(ctx.*) {
            .OPEN_GL => .{
                .OPEN_GL = opengl.OpenGLTexture.init(ctx.OPEN_GL, image),
            },
            .VULKAN => .{
                .VULKAN = vulkan.VulkanTexture.init(ctx.VULKAN, image),
            },
            .NONE => .{
                .NONE = log.not_implemented("Texture::init", ctx.*),
            },
        };
    }

    pub fn set_data(self: *const Texture, image: *const Image) void {
        switch(self.*) {
            .OPEN_GL => self.OPEN_GL.set_data(image),
            .VULKAN => self.VULKAN.set_data(image),
            inline else => log.not_implemented("Texture::deinit", self.*),
        }

    }

    pub fn sampler(self: *const Texture, options: SamplerOptions) TextureSampler {
        return switch(self.*) {
            .OPEN_GL => self.OPEN_GL.sampler(options),
            .VULKAN => self.VULKAN.sampler(options),
            inline else => {
                log.not_implemented("Texture::sampler", self.*);
                return TextureSampler{
                    .NONE = {},
                };
            }
        };
    }

    pub fn deinit(self: *const Texture) void {
        switch(self.*) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            .VULKAN => self.VULKAN.deinit(),
            inline else => log.not_implemented("Texture::deinit", self.*),
        }
    }
};

pub const TextureSampler = union(context.API) {
    OPEN_GL : opengl.OpenGLTextureSampler,
    VULKAN: vulkan.VulkanTextureSampler,
    NONE: void,

    pub fn deinit(self: *const TextureSampler) void {
        switch(self.*) {
            .OPEN_GL => self.OPEN_GL.deinit(),
            .VULKAN => self.VULKAN.deinit(),
            inline else => log.not_implemented("TextureSampler::deinit", self.*),
        }
    }
};
