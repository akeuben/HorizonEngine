pub const slang = @import("slang");
const std = @import("std");
const shader = @import("./shader.zig");

pub fn SlangSession(comptime Target: slang.CompileTarget, comptime Profile: [*:0]const u8) type {
    return struct {
        pub const Module = slang.IModule;
        pub const ComponentType = slang.IComponentType;
        pub const Program = SlangProgram;
        pub const _slang = slang;

        var instance: ?@This() = null;

        globalSession: *slang.IGlobalSession,

        pub fn getSession() !@This(){
            if(instance == null) {
                const globalSession = try slang.createGlobalSession(.{ .enable_glsl = true });
                instance = @This(){
                    .globalSession = globalSession,
                };
            }

            return instance.?;
        }

        pub fn compileProgram(self: @This(), name: [*:0]const u8, source: [:0]const u8, comptime entryPoints: []const [*:0]const u8) !SlangProgram {
            const profile = self.globalSession.findProfile(Profile);

            const target: []const slang.TargetDesc = @ptrCast(&slang.TargetDesc{
                .format = Target,
                .profile = profile,
            });
            const description = slang.SessionDesc{
                .targets = target,
            };
            const session = try self.globalSession.createSession(description);
            const module = session.loadModuleFromSource(name, name, source, null) orelse {
                std.log.err("Failed to shader module from source", .{});
                return shader.ShaderError.CompilationError;
            };

            var components: [entryPoints.len + 1]*slang.IComponentType = undefined;

            components[0] = @ptrCast(module);

            for(entryPoints, 1..) |entryPoint, i| {
                components[i] = @ptrCast(try module.findEntryPointByName(entryPoint));
            }

            const component = session.createCompositeComponentType(&components, null) catch {
                std.log.err("Failed to create composite shader type", .{});
                return shader.ShaderError.LinkingError;
            };

            return SlangProgram{
                .module = module,
                .session = session,
                .component = component,
            };

        }
    };
}

pub const SlangProgram = struct {
    module: *slang.IModule,
    session: *slang.ISession,
    component: *slang.IComponentType,
};
