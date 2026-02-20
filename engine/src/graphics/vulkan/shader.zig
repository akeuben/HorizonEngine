const context = @import("context.zig");
const vk = @import("vulkan");
const log = @import("../../utils/log.zig");
const ShaderError = @import("../shader.zig").ShaderError;
const BufferLayout = @import("../type.zig").BufferLayout;
const VulkanRenderTarget = @import("target.zig").VulkanRenderTarget;
const ShaderBindingLayout = @import("../shader.zig").ShaderBindingLayout;
const ShaderBindingLayoutElement = @import("../shader.zig").ShaderBindingLayoutElement;
const ShaderBindingLayoutElementType = @import("../shader.zig").ShaderBindingLayoutElementType;
const CreateInfoShaderBindingElement = @import("../shader.zig").CreateInfoShaderBindingElement;
const ShaderBindingElement = @import("../shader.zig").ShaderBindingElement;
const std = @import("std");
const types = @import("../type.zig");
const MAX_FRAMES_IN_FLIGHT = @import("./swapchain.zig").MAX_FRAMES_IN_FLIGHT;
const memory = @import("memory.zig");

const Slang = @import("../slang.zig").SlangSession(.spirv, "spirv_1_5");

pub const VulkanShader = struct {
    module: vk.ShaderModule,
    ctx: *const context.VulkanContext,

    pub fn init(ctx: *const context.VulkanContext, code: []const u8) ShaderError!VulkanShader {
        const create_info = vk.ShaderModuleCreateInfo{
            .code_size = @intCast(code.len),
            .p_code = @ptrCast(@alignCast(code.ptr)),
        };
        const module = ctx.logical_device.device.createShaderModule(&create_info, null) catch {
            log.err("Failed to initialize vulkan shader", .{});
            return ShaderError.CompilationError;
        };
        return .{
            .module = module,
            .ctx = ctx,
        };
    }
    pub fn deinit(self: VulkanShader) void {
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
    shader: Slang.Program,
    bindingsLayout: VulkanShaderBindingLayout,
    context: *const context.VulkanContext,

    pub fn init(ctx: *const context.VulkanContext, source: [:0]const u8, layout: *const BufferLayout) ShaderError!VulkanPipeline {
        const session = Slang.getSession() catch return ShaderError.ReadError;
        const shader = session.compileProgram("shader", source, &.{"vertex", "fragment"}) catch return ShaderError.CompilationError;

        const vertexSource = shader.component.getEntryPointCode(0, 0, null) catch return ShaderError.LinkingError;
        const fragmentSource = shader.component.getEntryPointCode(1, 0, null) catch return ShaderError.LinkingError;

        const vertex_shader = try VulkanShader.init(ctx, vertexSource.getBuffer());
        const fragment_shader = try VulkanShader.init(ctx, fragmentSource.getBuffer());
        
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

        const bindingsLayout = createLayout(ctx, shader) catch return ShaderError.CompilationError;

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

        const attribute_descriptions = ctx.allocator.alloc(vk.VertexInputAttributeDescription, layout.elements.len) catch {
            return ShaderError.LinkingError;
        };
        defer ctx.allocator.free(attribute_descriptions);
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
            .primitive_restart_enable = .false,
        };

        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .viewport_count = 1,
            .scissor_count = 1,
        };

        const rasterizer = vk.PipelineRasterizationStateCreateInfo{
            .depth_clamp_enable = .false,
            .rasterizer_discard_enable = .false,
            .polygon_mode = .fill,
            .cull_mode = .{ .back_bit = true },
            .front_face = .counter_clockwise,
            .depth_bias_enable = .false,
            .depth_bias_constant_factor = 0.0,
            .depth_bias_clamp = 0.0,
            .depth_bias_slope_factor = 0.0,
            .line_width = 1.0,
        };

        const multisampling = vk.PipelineMultisampleStateCreateInfo{
            .sample_shading_enable = .false,
            .rasterization_samples = .{ .@"1_bit" = true },
            .min_sample_shading = 1.0,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = .false,
            .alpha_to_one_enable = .false,
        };

        const color_blend_attachement = vk.PipelineColorBlendAttachmentState{
            .blend_enable = .true,
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
            .logic_op_enable = .false,
            .logic_op = .copy,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&color_blend_attachement),
            .blend_constants = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        };

        const pipeline_layout = vk.PipelineLayoutCreateInfo{
            .set_layout_count = 1,
            .p_set_layouts = @ptrCast(&bindingsLayout.layout),
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
            .depth_attachment_format = ctx.swapchain.depth_format,
            .stencil_attachment_format = if (memory.has_stencil_component(ctx.swapchain.depth_format)) ctx.swapchain.depth_format else undefined,
        };

        const depth_stencil = vk.PipelineDepthStencilStateCreateInfo{
            .depth_test_enable = .true,
            .depth_write_enable = .true,
            .depth_compare_op = .less,
            .min_depth_bounds = 0.0,
            .max_depth_bounds = 1.0,
            .stencil_test_enable = .false,
            .depth_bounds_test_enable = .false,
            .front = undefined,
            .back = undefined,
        };

        const create_info = vk.GraphicsPipelineCreateInfo{
            .stage_count = 2,
            .p_stages = @ptrCast(shader_stages),
            .p_vertex_input_state = @ptrCast(&vertex_input_info),
            .p_input_assembly_state = @ptrCast(&input_assembly),
            .p_viewport_state = @ptrCast(&viewport_state),
            .p_rasterization_state = @ptrCast(&rasterizer),
            .p_multisample_state = @ptrCast(&multisampling),
            .p_depth_stencil_state = @ptrCast(&depth_stencil),
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
            .shader = shader,
            .bindingsLayout = bindingsLayout,
        };
    }

    pub fn createLayout(ctx: *const context.VulkanContext, shader: Slang.Program) !VulkanShaderBindingLayout {

        const layout = shader.component.getLayout(0, null) orelse unreachable;

        var elements = std.ArrayList(ShaderBindingLayoutElement){};
        defer elements.deinit(ctx.allocator);

        const parameterCount: usize = @intCast(layout.getParameterCount());
        for(0..parameterCount) |j| {
            const parameter = layout.getParameterByIndex(@intCast(j));

            const t = slang_type_to_shader_type(parameter.getType().getKind());

            if(t == null) {
                continue;
            }

            log.debug("Found bindable resource {s}", .{parameter.getName()});
            
            try elements.append(ctx.allocator, .{ 
                .name = std.mem.span(parameter.getName()), 
                .type = t.?,
                .point = parameter.getBindingIndex(), 
            });
        }

        return VulkanShaderBindingLayout.init(ctx, try elements.toOwnedSlice(ctx.allocator));
    }

    pub fn getLayout(self: VulkanPipeline) VulkanShaderBindingLayout {
        return self.bindingsLayout;
    }

    pub fn deinit(self: VulkanPipeline) void {
        self.context.logical_device.device.deviceWaitIdle() catch {};
        self.context.logical_device.device.destroyPipeline(self.pipeline, null);
        self.context.logical_device.device.destroyPipelineLayout(self.layout, null);
    }
};

fn slang_type_to_shader_type(t: @TypeOf(Slang._slang.TypeReflection.getKind(@ptrFromInt(10000)))) ?ShaderBindingLayoutElementType {
    return switch (t) {
        .constant_buffer => .UNIFORM_BUFFER,
        .resource => .IMAGE_SAMPLER,
        else => {
            log.debug("Unhandled shader parameter type {}", .{t});
            return null;
        }
    };
}

fn binding_type_to_vulkan_type(t: ShaderBindingLayoutElementType) vk.DescriptorType {
    return switch(t) {
        .UNIFORM_BUFFER => vk.DescriptorType.uniform_buffer,  
        .IMAGE_SAMPLER => vk.DescriptorType.combined_image_sampler,
    };
}

fn create_element(binding: *const ShaderBindingLayoutElement, element: *anyopaque) ShaderBindingElement {
    return switch(binding.type) {
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

    pub fn init(ctx: *const context.VulkanContext, bindings: []ShaderBindingLayoutElement) VulkanShaderBindingLayout {
        const vk_bindings = ctx.allocator.alloc(vk.DescriptorSetLayoutBinding, bindings.len) catch unreachable;
        defer ctx.allocator.free(vk_bindings);

        for(bindings, 0..) |binding, i| {
            vk_bindings[i] = vk.DescriptorSetLayoutBinding{
                .binding = binding.point,
                .descriptor_count = 1,
                .descriptor_type = binding_type_to_vulkan_type(binding.type),
                .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
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

    pub fn create(self: VulkanShaderBindingLayout, bindings: []const CreateInfoShaderBindingElement) VulkanShaderBindingSet {
        var layouts: [MAX_FRAMES_IN_FLIGHT] vk.DescriptorSetLayout = undefined;
        
        for(0..MAX_FRAMES_IN_FLIGHT) |i| {
            layouts[i] = self.layout;
        }

        const allocInfo = vk.DescriptorSetAllocateInfo{
            .descriptor_pool = self.ctx.descriptor_pool,
            .descriptor_set_count = MAX_FRAMES_IN_FLIGHT,
            .p_set_layouts = @ptrCast(&layouts[0]),
        };

        var descriptor_sets: [MAX_FRAMES_IN_FLIGHT] vk.DescriptorSet = undefined;

        self.ctx.logical_device.device.allocateDescriptorSets(&allocInfo, @ptrCast(&descriptor_sets[0])) catch {
            log.fatal("Failed to allocate descriptor sets for UBO", .{});
        };

        const writes = self.ctx.allocator.alloc(vk.WriteDescriptorSet, bindings.len * MAX_FRAMES_IN_FLIGHT) catch unreachable;
        var count: u32 = 0;

        for(bindings) |binding| {
            for(self.bindings) |lbinding| {
                if(!std.mem.eql(u8, binding.point, lbinding.name)) continue;
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
                                .dst_binding = lbinding.point,
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
                                .dst_binding = lbinding.point,
                                .dst_array_element = 0,
                                .descriptor_type = .combined_image_sampler,
                                .descriptor_count = 1,
                                .p_buffer_info = undefined,
                                .p_image_info = @ptrCast(&image_info),
                                .p_texel_buffer_view = undefined,
                            };

                            log.debug("binding at {s}", .{binding.point});

                            writes[count] = descriptor_write;
                            count += 1;
                            log.debug("Write image sampler", .{});
                        },
                    }
                }
            }
        }
        self.ctx.logical_device.device.updateDescriptorSets(count, @ptrCast(writes.ptr), 0, null);
        log.debug("Wrote {} descriptor sets", .{count});

        return VulkanShaderBindingSet{
            .layout = self.layout,
            .descriptor_sets = descriptor_sets,
        };
    }
        

    pub fn deinit(self: *const VulkanShaderBindingLayout) void {
        self.ctx.logical_device.device.destroyDescriptorSetLayout(self.layout, null);
        self.ctx.allocator.free(self.bindings);
    }
};

pub const VulkanShaderBindingSet = struct {
    layout: vk.DescriptorSetLayout,
    descriptor_sets: [MAX_FRAMES_IN_FLIGHT] vk.DescriptorSet,
};
