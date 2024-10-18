const zm = @import("zm");

pub const BufferLayoutElement = struct {
    size: u32,
    length: usize,
    offset: u32,
};

pub const BufferLayout = struct {
    size: u32,
    length: usize,
    elements: []BufferLayoutElement,
};

pub const ShaderTypeInfo = struct { size: u32, length: usize };
pub const ShaderTypeError = error{ InvalidShaderType, OutOfMemory };

pub fn resolve_shader_type_info(comptime T: type) ShaderTypeError!ShaderTypeInfo {
    return comptime switch (T) {
        f32 => ShaderTypeInfo{ .size = @sizeOf(f32), .length = 1 },
        f64 => ShaderTypeInfo{ .size = @sizeOf(f64), .length = 1 },
        zm.Vec2f => ShaderTypeInfo{ .size = @sizeOf(zm.Vec2f), .length = 2 },
        zm.Vec3f => ShaderTypeInfo{ .size = @sizeOf(zm.Vec3f), .length = 3 },
        zm.Vec4f => ShaderTypeInfo{ .size = @sizeOf(zm.Vec4f), .length = 4 },
        zm.Vec2d => ShaderTypeInfo{ .size = @sizeOf(zm.Vec2d), .length = 2 },
        zm.Vec3d => ShaderTypeInfo{ .size = @sizeOf(zm.Vec3d), .length = 3 },
        zm.Vec4d => ShaderTypeInfo{ .size = @sizeOf(zm.Vec4d), .length = 4 },
        zm.Mat2f => ShaderTypeInfo{ .size = @sizeOf(zm.Mat2f), .length = 4 },
        zm.Mat3f => ShaderTypeInfo{ .size = @sizeOf(zm.Mat3f), .length = 9 },
        zm.Mat4f => ShaderTypeInfo{ .size = @sizeOf(zm.Mat4f), .length = 16 },
        zm.Mat2d => ShaderTypeInfo{ .size = @sizeOf(zm.Mat2d), .length = 4 },
        zm.Mat3d => ShaderTypeInfo{ .size = @sizeOf(zm.Mat3d), .length = 9 },
        zm.Mat4d => ShaderTypeInfo{ .size = @sizeOf(zm.Mat4d), .length = 16 },
        else => ShaderTypeError.InvalidShaderType,
    };
}
