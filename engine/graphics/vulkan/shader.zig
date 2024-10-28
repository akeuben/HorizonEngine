const context = @import("context.zig");
const vk = @import("vulkan");
const log = @import("../../utils/log.zig");
const ShaderError = @import("../shader.zig").ShaderError;
const BufferLayout = @import("../type.zig").BufferLayout;
const VulkanRenderTarget = @import("target.zig").VulkanRenderTarget;

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
    pipeline: vk.Pipeline,
    context: *const context.VulkanContext,

    pub fn init(ctx: *const context.VulkanContext, vertex_shader: VulkanVertexShader, fragment_shader: VulkanFragmentShader, _: *const BufferLayout, target: *const VulkanRenderTarget) ShaderError!VulkanPipeline {
        const vertex_shader_stage_info = vk.PipelineShaderStageCreateInfo{
            .stage = .{ .vertex_bit = true, .fragment_bit = false },
            .module = vertex_shader.module,
            .p_name = "main",
        };

        const fragment_shader_stage_info = vk.PipelineShaderStageCreateInfo{
            .stage = .{ .fragment_bit = true, .vertex_bit = false },
            .module = fragment_shader.module,
            .p_name = "main",
        };

        const shader_stages = &.{ vertex_shader_stage_info, fragment_shader_stage_info };
        const dynamic_states: []const vk.DynamicState = &.{ .viewport, .scissor };

        const dynamic_state = vk.PipelineDynamicStateCreateInfo{
            .dynamic_state_count = @intCast(dynamic_states.len),
            .p_dynamic_states = @ptrCast(dynamic_states.ptr),
        };

        const vertex_input_info = vk.PipelineVertexInputStateCreateInfo{
            .vertex_binding_description_count = 0,
            .p_vertex_binding_descriptions = null,
            .vertex_attribute_description_count = 0,
            .p_vertex_attribute_descriptions = null,
        };

        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
            .topology = .triangle_list,
            .primitive_restart_enable = vk.FALSE,
        };

        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .viewport_count = 1,
            .scissor_count = 1,
        };

        const rasterizer = vk.PipelineRasterizationStateCreateInfo{
            .depth_clamp_enable = vk.FALSE,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = .fill,
            .line_width = 1.0,
            .cull_mode = .{ .back_bit = true },
            .front_face = .clockwise,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0.0,
            .depth_bias_clamp = 0.0,
            .depth_bias_slope_factor = 0.0,
        };

        const multisampling = vk.PipelineMultisampleStateCreateInfo{
            .sample_shading_enable = vk.FALSE,
            .rasterization_samples = .{ .@"1_bit" = true },
            .min_sample_shading = 1.0,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };

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

        const pipeline_layout = vk.PipelineLayoutCreateInfo{ .set_layout_count = 0, .p_set_layouts = null, .push_constant_range_count = 0, .p_push_constant_ranges = null };

        const layout = ctx.logical_device.device.createPipelineLayout(&pipeline_layout, null) catch {
            return ShaderError.LinkingError;
        };

        const create_info = vk.GraphicsPipelineCreateInfo{
            .stage_count = 2,
            .p_stages = @ptrCast(shader_stages),
            .p_vertex_input_state = @ptrCast(&vertex_input_info),
            .p_input_assembly_state = @ptrCast(&input_assembly),
            .p_viewport_state = @ptrCast(&viewport_state),
            .p_rasterization_state = @ptrCast(&rasterizer),
            .p_multisample_state = @ptrCast(&multisampling),
            .p_depth_stencil_state = null,
            .p_color_blend_state = @ptrCast(&color_blending),
            .p_dynamic_state = @ptrCast(&dynamic_state),
            .layout = layout,
            .render_pass = target.get_renderpass(),
            .subpass = 0,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        };
        var pipeline: vk.Pipeline = undefined;
        const result = ctx.logical_device.device.createGraphicsPipelines(.null_handle, 1, @ptrCast(&create_info), null, @ptrCast(&pipeline)) catch {
            return ShaderError.LinkingError;
        };
        if (result != .success) {
            return ShaderError.LinkingError;
        }

        return VulkanPipeline{
            .layout = layout,
            .pipeline = pipeline,
            .context = ctx,
        };
    }
    pub fn deinit(self: VulkanPipeline) void {
        self.context.logical_device.device.deviceWaitIdle() catch {};
        self.context.logical_device.device.destroyPipeline(self.pipeline, null);
        self.context.logical_device.device.destroyPipelineLayout(self.layout, null);
    }

    pub fn bind(_: VulkanPipeline) void {}
};
