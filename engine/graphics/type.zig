const std = @import("std");
const zm = @import("zm");

pub const ShaderLayoutElementType = enum {
    Vec1f,
    Vec2f,
    Vec3f,
    Vec4f,
    Vec1d,
    Vec2d,
    Vec3d,
    Vec4d,
    Mat2f,
    Mat3f,
    Mat4f,
    Mat2d,
    Mat3d,
    Mat4d,
};

pub const BufferLayoutElement = struct {
    size: u32,
    length: usize,
    offset: u32,
    shader_type: ShaderLayoutElementType,
};

pub const BufferLayout = struct {
    size: u32,
    length: usize,
    elements: []BufferLayoutElement,
};

pub const ShaderTypeInfo = struct { size: u32, length: usize, shader_type: ShaderLayoutElementType };
pub const ShaderTypeError = error{ InvalidShaderType, OutOfMemory };

pub fn generate_layout(comptime T: type, data: []const T) ShaderTypeError!BufferLayout {
    const len = comptime std.meta.fields(T).len;
    var elements = std.heap.page_allocator.alloc(BufferLayoutElement, len) catch {
        return ShaderTypeError.OutOfMemory;
    };

    inline for (comptime std.meta.fields(T), 0..) |field, i| {
        const attribute_descriptor = resolve_shader_type_info(field.type) catch {
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
    };
}

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
