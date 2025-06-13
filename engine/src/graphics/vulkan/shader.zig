const context = @import("context.zig");
const vk = @import("vulkan");
const log = @import("../../utils/log.zig");
const ShaderError = @import("../shader.zig").ShaderError;
const BufferLayout = @import("../type.zig").BufferLayout;
const VulkanRenderTarget = @import("target.zig").VulkanRenderTarget;
const std = @import("std");
const types = @import("../type.zig");

const shaderc = @import("shaderc");

var compiler: shaderc.Compiler = undefined;
var initialized = false;

pub const VulkanVertexShader = struct {
    module: vk.ShaderModule,
    ctx: *const context.VulkanContext,

    pub fn init(ctx: *const context.VulkanContext, sourceCode: []const u8) ShaderError!VulkanVertexShader {
        if(!initialized) {
            compiler = shaderc.Compiler.initialize();
            initialized = true;
        }
        const options = shaderc.CompileOptions.initialize();
        defer options.release();
        options.setOptimizationLevel(shaderc.OptimizationLevel.Zero);
        options.setSourceLanguage(shaderc.SourceLanguage.GLSL);
        options.setVersion(shaderc.Env.Target.Vulkan, shaderc.Env.VulkanVersion.@"3");
        const result = compiler.compileIntoSpv(ctx.allocator, sourceCode, shaderc.ShaderKind.Vertex, "main", options) catch |e| {
            log.err("Failed to compile vertex shader: {}", .{e});
            return ShaderError.CompilationError;
        };
        if(result.getCompilationStatus() == .Success) {
            log.debug("Compiled (1) vertex shader.", .{});
        } else {
            log.err("Failed to compile vertex shader: {s}", .{result.getErrorMessage()});
            return ShaderError.CompilationError;
        }
        const data = result.getBytes();
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

    pub fn init(ctx: *const context.VulkanContext, sourceCode: []const u8) ShaderError!VulkanFragmentShader {
        if(initialized) {
            compiler = shaderc.Compiler.initialize();
            initialized = true;
        }
        const options = shaderc.CompileOptions.initialize();
        defer options.release();
        options.setOptimizationLevel(shaderc.OptimizationLevel.Zero);
        options.setSourceLanguage(shaderc.SourceLanguage.GLSL);
        options.setVersion(shaderc.Env.Target.Vulkan, shaderc.Env.VulkanVersion.@"3");
        const result = compiler.compileIntoSpv(ctx.allocator, sourceCode, shaderc.ShaderKind.Fragment, "main", options) catch |e| {
            log.err("Failed to compile fragment shader: {}", .{e});
            return ShaderError.CompilationError;
        };
        if(result.getCompilationStatus() == .Success) {
            log.debug("Compiled (1) fragment shader.", .{});
        } else {
            log.err("Failed to compile fragment shader: {s}", .{result.getErrorMessage()});
            return ShaderError.CompilationError;
        }
        const data = result.getBytes();
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

fn shader_type_to_vulkan_type(shader_type: types.ShaderLayoutElementType) vk.Format {
    return switch (shader_type) {
        .Vec1f => vk.Format.r32_sfloat,
        .Vec2f => vk.Format.r32g32_sfloat,
        .Vec3f => vk.Format.r32g32b32_sfloat,
        .Vec4f => vk.Format.r32g32b32a32_sfloat,
        .Vec1d => vk.Format.r64_sfloat,
        .Vec2d => vk.Format.r64g64_sfloat,
        .Vec3d => vk.Format.r64g64b64_sfloat,
        .Vec4d => vk.Format.r64g64b64a64_sfloat,
        else => {
            log.fatal("Invalid vertex buffer element type", .{});
            unreachable;
        },
    };
}

pub const VulkanPipeline = struct {
    layout: vk.PipelineLayout,
    pipeline: vk.Pipeline,
    context: *const context.VulkanContext,

    pub fn init(ctx: *const context.VulkanContext, vertex_shader: VulkanVertexShader, fragment_shader: VulkanFragmentShader, layout: *const BufferLayout) ShaderError!VulkanPipeline {
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

        const shader_stages: []const vk.PipelineShaderStageCreateInfo = &.{ vertex_shader_stage_info, fragment_shader_stage_info };
        const dynamic_states: []const vk.DynamicState = &.{ .viewport, .scissor };

        const dynamic_state = vk.PipelineDynamicStateCreateInfo{
            .dynamic_state_count = @intCast(dynamic_states.len),
            .p_dynamic_states = @ptrCast(dynamic_states.ptr),
        };

        const binding_description = vk.VertexInputBindingDescription{
            .binding = 0,
            .stride = layout.size,
            .input_rate = .vertex,
        };

        const attribute_descriptions = std.heap.page_allocator.alloc(vk.VertexInputAttributeDescription, layout.elements.len) catch {
            return ShaderError.LinkingError;
        };
        defer std.heap.page_allocator.free(attribute_descriptions);
        for (layout.elements, 0..) |element, i| {
            attribute_descriptions[i] = vk.VertexInputAttributeDescription{
                .binding = 0,
                .location = @intCast(i),
                .format = shader_type_to_vulkan_type(element.shader_type),
                .offset = element.offset,
            };
        }

        const vertex_input_info = vk.PipelineVertexInputStateCreateInfo{
            .vertex_binding_description_count = 1,
            .p_vertex_binding_descriptions = @ptrCast(&binding_description),
            .vertex_attribute_description_count = @intCast(attribute_descriptions.len),
            .p_vertex_attribute_descriptions = @ptrCast(attribute_descriptions.ptr),
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
            .cull_mode = .{ .back_bit = false },
            .front_face = .clockwise,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0.0,
            .depth_bias_clamp = 0.0,
            .depth_bias_slope_factor = 0.0,
            .line_width = 1.0,
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
            .blend_enable = vk.TRUE,
            .src_color_blend_factor = .src_alpha,
            .dst_color_blend_factor = .one_minus_src_alpha,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
            .color_write_mask = .{
                .r_bit = true,
                .g_bit = true,
                .b_bit = true,
                .a_bit = true,
            },
        };

        const color_blending = vk.PipelineColorBlendStateCreateInfo{
            .logic_op_enable = vk.FALSE,
            .logic_op = .copy,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&color_blend_attachement),
            .blend_constants = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        };

        const pipeline_layout = vk.PipelineLayoutCreateInfo{
            .set_layout_count = 0,
            .p_set_layouts = null,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = null,
        };

        const vk_layout = ctx.logical_device.device.createPipelineLayout(&pipeline_layout, null) catch {
            return ShaderError.LinkingError;
        };

        const rendering_create_info = vk.PipelineRenderingCreateInfo {
            .color_attachment_count = 1,
            .p_color_attachment_formats = @ptrCast(&ctx.swapchain.format),
            .view_mask = 0,
            .depth_attachment_format = ctx.swapchain.format,
            .stencil_attachment_format = ctx.swapchain.format,
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
            .layout = vk_layout,
            .subpass = 0,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
            .p_next = &rendering_create_info,
        };
        var pipeline: vk.Pipeline = undefined;
        const result = ctx.logical_device.device.createGraphicsPipelines(.null_handle, 1, @ptrCast(&create_info), null, @ptrCast(&pipeline)) catch {
            return ShaderError.LinkingError;
        };
        if (result != .success) {
            return ShaderError.LinkingError;
        }

        return VulkanPipeline{
            .layout = vk_layout,
            .pipeline = pipeline,
            .context = ctx,
        };
    }
    pub fn deinit(self: VulkanPipeline) void {
        self.context.logical_device.device.deviceWaitIdle() catch {};
        self.context.logical_device.device.destroyPipeline(self.pipeline, null);
        self.context.logical_device.device.destroyPipelineLayout(self.layout, null);
    }
};
