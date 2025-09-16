const std = @import("std");
const c = @import("c");

const shaderc = @This();

pub const Compilation = struct {
    pub const Result = struct {
        handle: c.shaderc.shaderc_compilation_result_t,

        pub fn release(self: @This()) void {
            c.shaderc.shaderc_result_release(self.handle);
        }

        pub fn getBytes(self: @This()) []const u8 {
            const length = c.shaderc.shaderc_result_get_length(self.handle);
            const bytes = c.shaderc.shaderc_result_get_bytes(self.handle);
            return std.mem.sliceAsBytes(bytes[0..length]);
        }

        pub fn getCompilationStatus(self: @This()) shaderc.Compilation.Status {
            return @enumFromInt(c.shaderc.shaderc_result_get_compilation_status(self.handle));
        }

        pub fn getErrorMessage(self: @This()) []const u8 {
            return std.mem.span(@as([*:0]const u8, @ptrCast(c.shaderc.shaderc_result_get_error_message(self.handle))));
        }
    };

    pub const Status = enum(c.shaderc.shaderc_compilation_status) {
        Success = c.shaderc.shaderc_compilation_status_success,
        InvalidStage = c.shaderc.shaderc_compilation_status_invalid_stage,
        CompilationError = c.shaderc.shaderc_compilation_status_compilation_error,
        InternalError = c.shaderc.shaderc_compilation_status_internal_error,
        NullResultObject = c.shaderc.shaderc_compilation_status_null_result_object,
        InvalidAssembly = c.shaderc.shaderc_compilation_status_invalid_assembly,
        ValidationError = c.shaderc.shaderc_compilation_status_validation_error,
        TransformationError = c.shaderc.shaderc_compilation_status_transformation_error,
        ConfigurationError = c.shaderc.shaderc_compilation_status_configuration_error,
    };
};

pub const CompileOptions = struct {
    handle: c.shaderc.shaderc_compile_options_t,

    pub fn initialize() @This() {
        return .{
            .handle = c.shaderc.shaderc_compile_options_initialize(),
        };
    }

    pub fn release(self: @This()) void {
        c.shaderc.shaderc_compile_options_release(self.handle);
    }

    pub fn setIncludeCallbacks(self: @This(), resolve_fn: c.shaderc.shaderc_include_resolve_fn, release_fn: c.shaderc.shaderc_include_result_release_fn, context: ?*anyopaque) void {
        c.shaderc.shaderc_compile_options_set_include_callbacks(self.handle, resolve_fn, release_fn, context);
    }

    pub fn setOptimizationLevel(self: @This(), opt: shaderc.OptimizationLevel) void {
        c.shaderc.shaderc_compile_options_set_optimization_level(self.handle, @intFromEnum(opt));
    }

    pub fn setSourceLanguage(self: @This(), lang: shaderc.SourceLanguage) void {
        c.shaderc.shaderc_compile_options_set_source_language(self.handle, @intFromEnum(lang));
    }

    pub fn setVersion(self: @This(), env_target: shaderc.Env.Target, env_version: shaderc.Env.VulkanVersion) void {
        c.shaderc.shaderc_compile_options_set_target_env(self.handle, @intFromEnum(env_target), @intFromEnum(env_version));
    }
};

pub const Compiler = struct {
    handle: c.shaderc.shaderc_compiler_t,

    pub fn initialize() @This() {
        return .{
            .handle = c.shaderc.shaderc_compiler_initialize(),
        };
    }

    pub fn release(self: @This()) void {
        c.shaderc.shaderc_compiler_release(self.handle);
    }

    pub fn compileIntoSpv(self: @This(), allocator: std.mem.Allocator, source: []const u8, kind: shaderc.ShaderKind, symbol: []const u8, options: shaderc.CompileOptions) !shaderc.Compilation.Result {
        // The "input_file_name" is a null-termintated string. It is used as a
        // tag to identify the source string in cases like emitting error
        // messages. It doesn't have to be a 'file name'.
        // The "entry_point_name" null-terminated string defines the name of
        // the entry point to associate with this GLSL source:
        return .{
            .handle = c.shaderc.shaderc_compile_into_spv(self.handle, try allocator.dupeZ(u8, source), source.len, @intFromEnum(kind), try allocator.dupeZ(u8, symbol), "main", options.handle),
        };
    }
};

pub const Env = struct {
    pub const Target = enum(c.shaderc.shaderc_target_env) {
        Vulkan = c.shaderc.shaderc_target_env_vulkan,
        OpenGL = c.shaderc.shaderc_target_env_opengl,
    };

    pub const VulkanVersion = enum(c.shaderc.shaderc_env_version) {
        @"0" = c.shaderc.shaderc_env_version_vulkan_1_0,
        @"1" = c.shaderc.shaderc_env_version_vulkan_1_1,
        @"2" = c.shaderc.shaderc_env_version_vulkan_1_2,
        @"3" = c.shaderc.shaderc_env_version_vulkan_1_3,
        @"gl45" = c.shaderc.shaderc_env_version_opengl_4_5,
    };
};

pub const Include = struct {
    pub const Result = c.shaderc.shaderc_include_result;

    pub const Type = enum(c.shaderc.shaderc_include_type) {
        Relative = c.shaderc.shaderc_include_type_relative, // E.g. #include "source"
        Standard = c.shaderc.shaderc_include_type_standard, // E.g. #include <source>
    };
};

pub const OptimizationLevel = enum(c.shaderc.shaderc_optimization_level) {
    Zero = c.shaderc.shaderc_optimization_level_zero,
    Performance = c.shaderc.shaderc_optimization_level_performance,
};

pub const ShaderKind = enum(c.shaderc.shaderc_shader_kind) {
    Fragment = c.shaderc.shaderc_glsl_fragment_shader,
    Vertex = c.shaderc.shaderc_glsl_vertex_shader,

    const Extension = enum {
        @".frag",
        @".vert",
    };

    pub fn init(ext: []const u8) @This() {
        return switch (std.meta.stringToEnum(@This().Extension, ext).?) {
            .@".frag" => @This().Fragment,
            .@".vert" => @This().Vertex,
        };
    }
};

pub const SourceLanguage = enum(c.shaderc.shaderc_source_language) {
    GLSL = c.shaderc.shaderc_source_language_glsl,
    HLSL = c.shaderc.shaderc_source_language_hlsl,
};
