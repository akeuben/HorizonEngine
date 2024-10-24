const context = @import("context.zig");
const vk = @import("vulkan");
const log = @import("../../utils/log.zig");
const ShaderError = @import("../shader.zig").ShaderError;
pub const VulkanVertexShader = struct {
    module: vk.ShaderModule,
    ctx: *const context.VulkanContext,

    pub fn init(ctx: *const context.VulkanContext, data: []const u8) ShaderError!VulkanVertexShader {
        const create_info = vk.ShaderModuleCreateInfo{
            .code_size = @intCast(data.len),
            .p_code = @ptrCast(@alignCast(data.ptr)),
        };
        const module = ctx.logical_device.device.createShaderModule(&create_info, null) catch {
            log.err("Failed to initialize vulkan vertex shader", .{});
            return ShaderError.CompilationError;
        };
        return .{
            .module = module,
            .ctx = ctx,
        };
    }
    pub fn deinit(self: VulkanVertexShader) void {
        self.ctx.logical_device.device.destroyShaderModule(self.module, null);
    }
};

pub const VulkanFragmentShader = struct {
    module: vk.ShaderModule,
    ctx: *const context.VulkanContext,

    pub fn init(ctx: *const context.VulkanContext, data: []const u8) ShaderError!VulkanFragmentShader {
        const create_info = vk.ShaderModuleCreateInfo{
            .code_size = @intCast(data.len),
            .p_code = @ptrCast(@alignCast(data.ptr)),
        };
        const module = ctx.logical_device.device.createShaderModule(&create_info, null) catch {
            log.err("Failed to initialize vulkan fragment shader", .{});
            return ShaderError.CompilationError;
        };
        return .{
            .module = module,
            .ctx = ctx,
        };
    }
    pub fn deinit(self: VulkanFragmentShader) void {
        self.ctx.logical_device.device.destroyShaderModule(self.module, null);
    }
};

pub const VulkanPipeline = struct {
    layout: vk.PipelineLayout,

    pub fn init(ctx: context.VulkanContext, vertex_shader: VulkanVertexShader, fragment_shader: VulkanFragmentShader) ShaderError!VulkanPipeline {
        const vertex_shader_stage_info = vk.PipelineShaderStageCreateInfo{
            .stage = .{ .vertex_bit = true },
            .module = vertex_shader.module,
            .p_name = "main",
        };

        const fragment_shader_stage_info = vk.PipelineShaderStageCreateInfo{
            .stage = .{ .fragment_bit = true },
            .module = fragment_shader.module,
            .p_name = "main",
        };

        const shader_stages = &.{ vertex_shader_stage_info, fragment_shader_stage_info };
        shout(shader_stages);
        const dynamic_states: []const vk.DynamicState = &.{ .viewport, .scissor };

        const dynamic_state = vk.PipelineDynamicStateCreateInfo{
            .dynamic_state_count = @intCast(dynamic_states.len),
            .p_dynamic_states = @ptrCast(dynamic_states.ptr),
        };
        shout(&dynamic_state);

        const vertex_input_info = vk.PipelineVertexInputStateCreateInfo{
            .vertex_binding_description_count = 0,
            .p_vertex_binding_descriptions = null,
            .vertex_attribute_description_count = 0,
            .p_vertex_attribute_descriptions = null,
        };
        shout(&vertex_input_info);

        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
            .topology = .triangle_list,
            .primitive_restart_enable = vk.FALSE,
        };
        shout(&input_assembly);

        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .viewport_count = 1,
            .scissor_count = 1,
        };
        shout(&viewport_state);

        const rasterizer = vk.PipelineRasterizationStateCreateInfo{
            .depth_clamp_enable = vk.TRUE,
            .rasterizer_discard_enable = vk.TRUE,
            .polygon_mode = .fill,
            .line_width = 1.0,
            .cull_mode = .{ .back_bit = true },
            .front_face = .clockwise,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0.0,
            .depth_bias_clamp = 0.0,
            .depth_bias_slope_factor = 0.0,
        };
        shout(&rasterizer);

        const multisampling = vk.PipelineMultisampleStateCreateInfo{
            .sample_shading_enable = vk.FALSE,
            .rasterization_samples = .{ .@"1_bit" = true },
            .min_sample_shading = 1.0,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };
        shout(&multisampling);

        const color_blend_attachement = vk.PipelineColorBlendAttachmentState{
            .blend_enable = vk.FALSE,
            .src_color_blend_factor = .one,
            .dst_color_blend_factor = .zero,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
        };

        const color_blending = vk.PipelineColorBlendStateCreateInfo{
            .logic_op_enable = vk.FALSE,
            .logic_op = .copy,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&color_blend_attachement),
            .blend_constants = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        };
        shout(&color_blending);

        const pipeline_layout = vk.PipelineLayoutCreateInfo{ .set_layout_count = 0, .p_set_layouts = null, .push_constant_range_count = 0, .p_push_constant_ranges = null };

        const layout = ctx.logical_device.device.createPipelineLayout(&pipeline_layout, null) catch {
            return ShaderError.LinkingError;
        };

        return VulkanPipeline{
            .layout = layout,
        };
    }
    pub fn deinit(_: VulkanPipeline) void {}

    pub fn bind(_: VulkanPipeline) void {}
};

fn shout(_: *const anyopaque) void {}
