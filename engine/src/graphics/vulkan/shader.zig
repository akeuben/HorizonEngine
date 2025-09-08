const context = @import("context.zig");
const vk = @import("vulkan");
const log = @import("../../utils/log.zig");
const ShaderError = @import("../shader.zig").ShaderError;
const BufferLayout = @import("../type.zig").BufferLayout;
const VulkanRenderTarget = @import("target.zig").VulkanRenderTarget;
const ShaderBindingLayoutElement = @import("../shader.zig").ShaderBindingLayoutElement;
const CreateInfoShaderBindingElement = @import("../shader.zig").CreateInfoShaderBindingElement;
const ShaderBindingType = @import("../shader.zig").ShaderBindingType;
const ShaderStage = @import("../shader.zig").ShaderStage;
const ShaderBindingElement = @import("../shader.zig").ShaderBindingElement;
const std = @import("std");
const types = @import("../type.zig");
const MAX_FRAMES_IN_FLIGHT = @import("./swapchain.zig").MAX_FRAMES_IN_FLIGHT;

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
        },
    };
}

pub const VulkanPipeline = struct {
    layout: vk.PipelineLayout,
    pipeline: vk.Pipeline,
    context: *const context.VulkanContext,

    pub fn init(ctx: *const context.VulkanContext, vertex_shader: VulkanVertexShader, fragment_shader: VulkanFragmentShader, layout: *const BufferLayout, bindings: *const VulkanShaderBindingSet) ShaderError!VulkanPipeline {
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
            .front_face = .counter_clockwise,
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
            .set_layout_count = 1,
            .p_set_layouts = @ptrCast(&bindings.layout),
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

fn binding_type_to_vulkan_type(t: ShaderBindingType) vk.DescriptorType {
    return switch(t) {
        .UNIFORM_BUFFER => vk.DescriptorType.uniform_buffer,  
        .IMAGE_SAMPLER => vk.DescriptorType.combined_image_sampler,
    };
}

fn stage_to_vulkan_type(t: ShaderStage) vk.ShaderStageFlags {
    return switch(t) {
        .VERTEX_SHADER => vk.ShaderStageFlags{ .vertex_bit = true }, 
        .FRAGMENT_SHADER => vk.ShaderStageFlags{ .fragment_bit = true},
    };
}

fn create_element(binding: *const ShaderBindingLayoutElement, element: *anyopaque) ShaderBindingElement {
    return switch(binding.binding_type) {
        .UNIFORM_BUFFER => ShaderBindingElement{
            .UNIFORM_BUFFER = @ptrCast(@alignCast(element)),
        },
        .IMAGE_SAMPLER => ShaderBindingElement{
            .IMAGE_SAMPLER = @ptrCast(@alignCast(element)),
        },
    };
}

pub const VulkanShaderBindingLayout = struct {
    ctx: *const context.VulkanContext,
    bindings: []const ShaderBindingLayoutElement,
    layout: vk.DescriptorSetLayout,

    pub fn init(ctx: *const context.VulkanContext, bindings: []const ShaderBindingLayoutElement) VulkanShaderBindingLayout {
        const vk_bindings = ctx.allocator.alloc(vk.DescriptorSetLayoutBinding, bindings.len) catch unreachable;

        for(bindings, 0..) |binding, i| {
            vk_bindings[i] = vk.DescriptorSetLayoutBinding{
                .binding = binding.point,
                .descriptor_count = 1,
                .descriptor_type = binding_type_to_vulkan_type(binding.binding_type),
                .stage_flags = stage_to_vulkan_type(binding.stage),
                .p_immutable_samplers = null,
            };
        }

        const create_info = vk.DescriptorSetLayoutCreateInfo{
            .binding_count = @intCast(vk_bindings.len),
            .p_bindings = vk_bindings.ptr,
        };

        const layout = ctx.logical_device.device.createDescriptorSetLayout(&create_info, null) catch {
            log.fatal("Failed to create descriptor set layout", .{});
        };

        return VulkanShaderBindingLayout{
            .ctx = ctx,
            .bindings = bindings,
            .layout = layout,
        };
    }

    pub fn deinit(self: *const VulkanShaderBindingLayout) void {
        self.ctx.logical_device.device.destroyDescriptorSetLayout(self.layout, null);
    }
};

pub const VulkanShaderBindingSet = struct {
    layout: vk.DescriptorSetLayout,
    descriptor_sets: [MAX_FRAMES_IN_FLIGHT] vk.DescriptorSet,

    pub fn init(ctx: *const context.VulkanContext, layout: *const VulkanShaderBindingLayout, bindings: []const CreateInfoShaderBindingElement) VulkanShaderBindingSet {
        var layouts: [MAX_FRAMES_IN_FLIGHT] vk.DescriptorSetLayout = undefined;
        
        for(0..MAX_FRAMES_IN_FLIGHT) |i| {
            layouts[i] = layout.layout;
        }

        const allocInfo = vk.DescriptorSetAllocateInfo{
            .descriptor_pool = ctx.descriptor_pool,
            .descriptor_set_count = MAX_FRAMES_IN_FLIGHT,
            .p_set_layouts = @ptrCast(&layouts[0]),
        };

        var descriptor_sets: [MAX_FRAMES_IN_FLIGHT] vk.DescriptorSet = undefined;

        ctx.logical_device.device.allocateDescriptorSets(&allocInfo, @ptrCast(&descriptor_sets[0])) catch {
            log.fatal("Failed to allocate descriptor sets for UBO", .{});
        };

        const writes = ctx.allocator.alloc(vk.WriteDescriptorSet, bindings.len * MAX_FRAMES_IN_FLIGHT) catch unreachable;
        var count: u32 = 0;

        for(bindings) |binding| {
            for(layout.bindings) |lbinding| {
                if(binding.point != lbinding.point) continue;
                for(0..MAX_FRAMES_IN_FLIGHT) |i| {
                    const element = create_element(&lbinding, binding.element);
                    switch(element) {
                        .UNIFORM_BUFFER => {
                            const buffer_info = vk.DescriptorBufferInfo{
                                .buffer = element.UNIFORM_BUFFER.VULKAN.vk_buffer[0].asVulkanBuffer(),
                                .offset = 0,
                                .range = element.UNIFORM_BUFFER.VULKAN.size,
                            };
                            
                            const descriptor_write = vk.WriteDescriptorSet{
                                .dst_set = descriptor_sets[i],
                                .dst_binding = binding.point,
                                .dst_array_element = 0,
                                .descriptor_type = .uniform_buffer,
                                .descriptor_count = 1,
                                .p_buffer_info = @ptrCast(&buffer_info),
                                .p_image_info = undefined,
                                .p_texel_buffer_view = undefined,
                            };

                            writes[count] = descriptor_write;
                            count += 1;
                        },
                        .IMAGE_SAMPLER => {
                            const image_info = vk.DescriptorImageInfo{
                                .image_layout = .shader_read_only_optimal,
                                .image_view = element.IMAGE_SAMPLER.VULKAN.view,
                                .sampler = element.IMAGE_SAMPLER.VULKAN.sampler,
                            };

                            const descriptor_write = vk.WriteDescriptorSet{
                                .dst_set = descriptor_sets[i],
                                .dst_binding = binding.point,
                                .dst_array_element = 0,
                                .descriptor_type = .combined_image_sampler,
                                .descriptor_count = 1,
                                .p_buffer_info = undefined,
                                .p_image_info = @ptrCast(&image_info),
                                .p_texel_buffer_view = undefined,
                            };

                            log.debug("binding at {}", .{binding.point});

                            writes[count] = descriptor_write;
                            count += 1;
                            log.debug("Write image sampler", .{});
                        },
                    }
                }
            }
        }
        ctx.logical_device.device.updateDescriptorSets(count, @ptrCast(writes.ptr), 0, null);
        log.debug("Wrote {} descriptor sets", .{count});
        
        
        return VulkanShaderBindingSet{
            .layout = layout.layout,
            .descriptor_sets = descriptor_sets,
        };
    }
};
