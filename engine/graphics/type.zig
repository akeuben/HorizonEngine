const ShaderTypeInfo = struct { size: u32, len: u32 };

pub const float = ShaderTypeInfo{ .size = @sizeOf(f32), .len = 1 };
pub const vec2 = ShaderTypeInfo{ .size = @sizeOf(f32), .len = 2 };
pub const vec3 = ShaderTypeInfo{ .size = @sizeOf(f32), .len = 3 };
pub const vec4 = ShaderTypeInfo{ .size = @sizeOf(f32), .len = 4 };
