///! This module is responsible for handling the manipulation and
///! generation of shader types for a Graphics API.
const std = @import("std");
const zm = @import("zm");

/// Types that can be represented in a shader
pub const ShaderLayoutElementType = enum {
    // A 1d vector of f32
    Vec1f,
    // A 2d vector of f32
    Vec2f,
    // A 3d vector of f32
    Vec3f,
    // A 4d vector of f32
    Vec4f,
    // A 1d vector of f64
    Vec1d,
    // A 2d vector of f64
    Vec2d,
    // A 3d vector of f64
    Vec3d,
    // A 4d vector of f64
    Vec4d,
    // A 2x2 matrix of f32
    Mat2f,
    // A 3x3 matrix of f32
    Mat3f,
    // A 4x4 matrix of f32
    Mat4f,
    // A 2x2 matrix of f64
    Mat2d,
    // A 3x3 matrix of f64
    Mat3d,
    // A 4x4 matrix of f64
    Mat4d,
};

/// An element of a buffer layout.
pub const BufferLayoutElement = struct {
    /// The size of the element in bytes
    size: u32,
    /// The number of elements of the element
    length: usize,
    /// The offset of the element in a buffer line
    offset: u32,
    /// The type of variable of the element
    shader_type: ShaderLayoutElementType,
};

/// The layout of a buffer
pub const BufferLayout = struct {
    /// The total size of the buffer layout
    size: u32,
    /// The number of elements
    length: usize,
    /// The elements
    elements: []BufferLayoutElement,
    /// The allocator used to create the element list
    allocator: std.mem.Allocator,

    /// Destroy the given buffer layout
    ///
    /// **Parameter** `self`: The buffer layout to destroy the elements list for.
    pub fn deinit(self: *BufferLayout) void {
        self.allocator.free(self.elements);
    }
};

/// Information about a shader type
pub const ShaderTypeInfo = struct {
    /// The size of the type in bytes
    size: u32,
    /// The number of dimensions of the type
    length: usize,
    /// The type
    shader_type: ShaderLayoutElementType,
};

/// An error pertaining to a shader type
pub const ShaderTypeError = error{
    /// The provided type cannot be converted to a shader type
    InvalidShaderType,
    // The provided type could not be found as the system is out of memory
    OutOfMemory,
};

/// Generate the layout of a given buffer
///
/// Ensure the Buffer layout is destroyed with `BufferLayout.deinit()` if the layut is no longer being used.
///
/// **Parameter** `T`: The type of the buffer to generate the data for
/// **Parameter** `data`: The data of the buffer
/// **Parameter** `allocator`: The allocator to use to generate the list of elements.
/// **Returns** the buffer layout
/// **Error** `OutOfMemory`: If the layout generation failed due to a lack of system memory.
/// **Error** `InvalidShaderType`: If the type `T` cannot be converted to a shader type.
pub fn generate_layout(comptime T: type, data: []const T, allocator: std.mem.Allocator) ShaderTypeError!BufferLayout {
    const len = comptime std.meta.fields(T).len;
    var elements = allocator.alloc(BufferLayoutElement, len) catch {
        return ShaderTypeError.OutOfMemory;
    };

    inline for (comptime std.meta.fields(T), 0..) |field, i| {
        const attribute_descriptor = resolve_shader_type_info(field.type) catch {
            allocator.free(elements);
            return ShaderTypeError.InvalidShaderType;
        };
        const element: BufferLayoutElement = .{
            .size = attribute_descriptor.size,
            .length = attribute_descriptor.length,
            .offset = @offsetOf(T, field.name),
            .shader_type = attribute_descriptor.shader_type,
        };
        elements[i] = element;
    }

    return BufferLayout{
        .size = @sizeOf(T),
        .length = data.len,
        .elements = elements,
        .allocator = allocator,
    };
}

/// Get the information for a shader type given a CPU type.
///
/// **Parameter** `T`: The type of the buffer to generate the data for
/// **Returns** The resolved shader type info
/// **Error** `InvalidShaderType`: If the type `T` cannot be converted to a shader type.
pub fn resolve_shader_type_info(comptime T: type) ShaderTypeError!ShaderTypeInfo {
    return comptime switch (T) {
        f32 => ShaderTypeInfo{ .size = @sizeOf(f32), .length = 1, .shader_type = .Vec1f },
        f64 => ShaderTypeInfo{ .size = @sizeOf(f64), .length = 1, .shader_type = .Vec1d },
        zm.Vec2f => ShaderTypeInfo{ .size = @sizeOf(zm.Vec2f), .length = 2, .shader_type = .Vec2f },
        zm.Vec3f => ShaderTypeInfo{ .size = @sizeOf(zm.Vec3f), .length = 3, .shader_type = .Vec3f },
        zm.Vec4f => ShaderTypeInfo{ .size = @sizeOf(zm.Vec4f), .length = 4, .shader_type = .Vec4f },
        zm.Vec2d => ShaderTypeInfo{ .size = @sizeOf(zm.Vec2d), .length = 2, .shader_type = .Vec2d },
        zm.Vec3d => ShaderTypeInfo{ .size = @sizeOf(zm.Vec3d), .length = 3, .shader_type = .Vec3d },
        zm.Vec4d => ShaderTypeInfo{ .size = @sizeOf(zm.Vec4d), .length = 4, .shader_type = .Vec4d },
        zm.Mat2f => ShaderTypeInfo{ .size = @sizeOf(zm.Mat2f), .length = 4, .shader_type = .Mat2f },
        zm.Mat3f => ShaderTypeInfo{ .size = @sizeOf(zm.Mat3f), .length = 9, .shader_type = .Mat3f },
        zm.Mat4f => ShaderTypeInfo{ .size = @sizeOf(zm.Mat4f), .length = 16, .shader_type = .Mat4f },
        zm.Mat2d => ShaderTypeInfo{ .size = @sizeOf(zm.Mat2d), .length = 4, .shader_type = .Mat2d },
        zm.Mat3d => ShaderTypeInfo{ .size = @sizeOf(zm.Mat3d), .length = 9, .shader_type = .Mat3d },
        zm.Mat4d => ShaderTypeInfo{ .size = @sizeOf(zm.Mat4d), .length = 16, .shader_type = .Mat4d },
        else => ShaderTypeError.InvalidShaderType,
    };
}
