const Context = @import("context.zig").VulkanContext;
const Image = @import("../texture.zig").Image;
const vk = @import("vulkan");
const memory = @import("memory.zig");
const allocator = @import("allocator.zig");
const log = @import("../../utils/log.zig");

const TextureSampler = @import("../texture.zig").TextureSampler;
const SamplerOptions = @import("../texture.zig").SamplerOptions;
const TextureFilter = @import("../texture.zig").TextureFilter;

pub const VulkanTexture = struct {
    ctx: *const Context,
    vk_image: ?allocator.AllocatedVulkanImage,

    pub fn init(ctx: *const Context, image: *const Image) VulkanTexture{
        var texture = VulkanTexture{
            .ctx = ctx,
            .vk_image = undefined,
        };

        texture.set_data(image);

        return texture;
    }

    pub fn set_data(self: *VulkanTexture, image: *const Image) void {
        if(self.vk_image != null) {
            self.deinit();
        }
        const size: u64 = @intCast(image.width * image.height * 4);
        const staging_buffer = self.ctx.vk_allocator.create_buffer(size, .{ .transfer_src_bit = true }, .{ .host_visible_bit = true, .host_coherent_bit = true });
        defer self.ctx.vk_allocator.destroy_buffer(staging_buffer);

        const map_ptr = self.ctx.vk_allocator.map_buffer(u8, staging_buffer);
        @memcpy(@as([*]u8, @alignCast(@ptrCast(map_ptr)))[0..size], @as([*]u8, @alignCast(@ptrCast(image.pixels)))[0..size]);
        self.ctx.vk_allocator.unmap_buffer(staging_buffer);

        const extent = vk.Extent3D{
            .width = @intCast(image.width),
            .height = @intCast(image.height),
            .depth = 1,
        };

        self.vk_image = self.ctx.vk_allocator.create_image(extent, .r8g8b8a8_srgb, .optimal, .{ .transfer_dst_bit = true,.sampled_bit = true, }, .{ .device_local_bit = true });
        
        memory.transition_image_layout(self.ctx, &self.vk_image.?, .r8g8b8a8_srgb, .undefined, vk.ImageLayout.transfer_dst_optimal);
        memory.copy_buffer_to_image(self.ctx, staging_buffer, self.vk_image.?, extent);
        memory.transition_image_layout(self.ctx, &self.vk_image.?, .r8g8b8a8_srgb, .transfer_dst_optimal, vk.ImageLayout.shader_read_only_optimal);

        log.debug("uploaded vulkan image", .{});
    }

    pub fn sampler(self: *const VulkanTexture, options: SamplerOptions) TextureSampler {
        return TextureSampler{
            .VULKAN = VulkanTextureSampler.init(self, options),
        };
    }

    pub fn deinit(self: *const VulkanTexture) void {
        self.ctx.vk_allocator.destroy_image(self.vk_image.?);
    }
};

fn filter_to_vulkan_type(filter: TextureFilter) vk.Filter {
    return switch(filter) {
        .LINEAR => vk.Filter.linear,
        .POINT => vk.Filter.nearest,
    };
}

pub const VulkanTextureSampler = struct {
    ctx: *const Context,
    view: vk.ImageView,
    sampler: vk.Sampler,

    fn init(texture: *const VulkanTexture, options: SamplerOptions) VulkanTextureSampler {
        
        const viewInfo = vk.ImageViewCreateInfo{
            .image = texture.vk_image.?.asVulkanImage(),
            .view_type = .@"2d",
            .format = .r8g8b8a8_srgb,
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
                .base_mip_level = 0,
            },
            .components = .{ .a = .identity, .r = .identity, .b = .identity, .g = .identity },
        };

        const view = texture.ctx.logical_device.device.createImageView(@ptrCast(&viewInfo), null) catch {
            log.err("Failed to create vulkan image view", .{});
            return undefined;
        };

        const deviceProperties = texture.ctx.instance.instance.getPhysicalDeviceProperties(texture.ctx.physical_device.device);

        const samplerInfo = vk.SamplerCreateInfo{
            .mag_filter = filter_to_vulkan_type(options.filter),
            .min_filter = filter_to_vulkan_type(options.filter),
            .address_mode_u = .repeat,
            .address_mode_v = .repeat,
            .address_mode_w = .repeat,
            .anisotropy_enable = vk.TRUE,
            .max_anisotropy = deviceProperties.limits.max_sampler_anisotropy,
            .border_color = .float_opaque_black,
            .unnormalized_coordinates = vk.FALSE,
            .compare_enable = vk.FALSE,
            .compare_op = .always,
            .mipmap_mode = .linear,
            .mip_lod_bias = 0.0,
            .min_lod = 0.0,
            .max_lod = 0.0,
        };

        const sampler = texture.ctx.logical_device.device.createSampler(@ptrCast(&samplerInfo), null) catch {
            log.err("Failed to create vulkan texture sampler", .{});
            return undefined;
        };

        log.debug("Created vulkan sampler", .{});

        return VulkanTextureSampler{
            .ctx = texture.ctx,
            .view = view,
            .sampler = sampler,
        };
    }

    pub fn deinit(self: *const VulkanTextureSampler) void {
        self.ctx.logical_device.device.destroySampler(self.sampler, null);
        self.ctx.logical_device.device.destroyImageView(self.view, null);
        log.debug("deinit texture sampler", .{});
    }
};
