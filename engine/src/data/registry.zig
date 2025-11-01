const std = @import("std");

const RegistryError = error {
    allocation_error,
    invalid_id
};

const RegistryFile = struct {
    root: union(enum) {
        root: void,
        builtin: void,
        mod: []const u8,
    },
    path: []const u8,
    namespace: []const u8,
};

pub const NamespacedId = struct {
    allocation: ?[]const u8 = null,
    allocator: ?*const std.mem.Allocator = null,
    namespace: []const u8,
    id: []const u8,

    pub const Context = struct {
        pub fn hash(_: @This(), id: NamespacedId) u64 {
            var h = std.hash.Wyhash.init(0);
            h.update(id.namespace);
            h.update(id.id);
            return h.final();
        }

        pub fn eql(_: @This(), a: NamespacedId, b: NamespacedId) bool {
            return std.mem.eql(u8, a.namespace, b.namespace) and std.mem.eql(u8, a.id, b.id);
        }
    };

    pub fn parse(str: []const u8, allocator: *const std.mem.Allocator) RegistryError!NamespacedId {
        const s = allocator.alloc(u8, str.len) catch RegistryError;
        errdefer allocator.free(s);

        @memcpy(s, str);

        const idx = std.mem.indexOfScalar(u8, s, ':') orelse
            return RegistryError.invalid_id;
        return NamespacedId{
            .namespace = s[0..idx],
            .id = s[idx+1..],
            .fullPath = s,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: NamespacedId) void {
        if(self.allocation) |allocation| {
            if(self.allocator) |allocator| {
                allocator.free(allocation);
            }
        }
    }

    pub fn format(
        self: NamespacedId,
        writer: anytype,
    ) !void {
        try writer.print("{s}:{s}", .{
            self.namespace, self.id,
        });
    }
};

const RegistryHashMap = std.HashMap(NamespacedId, RegistryFile, NamespacedId.Context, std.hash_map.default_max_load_percentage);

const JSONRegistryHashMap = std.HashMap(NamespacedId, std.json.Parsed(std.json.Value), NamespacedId.Context, std.hash_map.default_max_load_percentage);

fn findFiles(registryPath: []const u8, allocator: *const std.mem.Allocator, valid_ext: []const u8) ![]RegistryFile {
    var files = std.ArrayList(RegistryFile).empty;
    defer files.deinit(allocator.*);

    // walk app directory 
    const appDir: ?std.fs.Dir = std.fs.cwd().openDir("app", .{ .iterate = true }) catch null;
    if(appDir) |dir| {
        try findFilesInDir(&files, registryPath, allocator, valid_ext, dir);
    }

    return files.toOwnedSlice(allocator.*);
}

fn findFilesInDir(files: *std.ArrayList(RegistryFile), registryPath: []const u8, allocator: *const std.mem.Allocator, valid_ext: []const u8, dir: std.fs.Dir) !void {
    var iter = dir.iterate();
    while(try iter.next()) |file| {
        if(file.kind == .directory) {
            findFilesInDirNamespace(files, registryPath, allocator, valid_ext, dir, file.name) catch {
            };
        }
    }
}

fn findFilesInDirNamespace(files: *std.ArrayList(RegistryFile), registryPath: []const u8, allocator: *const std.mem.Allocator, valid_ext: []const u8, dir: std.fs.Dir, namespace: []const u8) !void {
    const p = try std.fs.path.join(allocator.*, &.{namespace, registryPath});
    defer allocator.free(p);

    const newDir = try dir.openDir(p, .{ .iterate = true });
    
    var iter = try newDir.walk(allocator.*);
    defer iter.deinit();
    while(try iter.next()) |file| {
        if(file.kind == .file and std.mem.endsWith(u8, file.basename, valid_ext)) {
            const idx = std.mem.indexOf(u8, file.path, valid_ext).?;
            const path = try allocator.alloc(u8, idx);
            @memcpy(path, file.path[0..idx]);
            const ns = try allocator.alloc(u8, namespace.len);
            @memcpy(ns, namespace);
            try files.append(allocator.*, RegistryFile{
                .path = path,
                .namespace = ns,
                .root = .root,
            });
        }
    }
}


fn freeFoundFiles(files: []RegistryFile, allocator: *const std.mem.Allocator) void {
    for(files) |file| {
        allocator.free(file.path);
        allocator.free(file.namespace);
    }
    allocator.free(files);
}

const RegistryInfo = struct {
    path: []const u8,
    type: enum {
        json
    },
};

pub const JSONRegistry = struct {

    path: []u8,
    entries: RegistryHashMap,
    loaded: JSONRegistryHashMap,
    allocator: *const std.mem.Allocator,

    files: []RegistryFile,
    
    pub fn init(allocator: *const std.mem.Allocator, path: []const u8) RegistryError!*JSONRegistry {
        const self = allocator.create(@This()) catch return RegistryError.allocation_error;
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.path = self.allocator.alloc(u8, path.len) catch return RegistryError.allocation_error;
        @memcpy(self.path, path);
        std.log.debug("JSON registry using path: {s}", .{self.path});

        self.entries = RegistryHashMap.init(self.allocator.*);
        errdefer self.entries.deinit();

        self.loaded = JSONRegistryHashMap.init(self.allocator.*);
        errdefer self.loaded.deinit();

        self.files = findFiles(path, allocator, ".json") catch return RegistryError.allocation_error;
        for(self.files) |file| {
            self.entries.put(.{.namespace = file.namespace, .id= file.path}, file) catch return RegistryError.allocation_error;
        }

        return self;
    }

    fn list(self: *const JSONRegistry) RegistryError!RegistryHashMap.KeyIterator {
        return self.entries.keyIterator();
    }

    pub fn load(self: *const JSONRegistry, id: NamespacedId, file: RegistryFile) !std.json.Parsed(std.json.Value) {
        const content = try RegistryBase.load(self.allocator, id, self.path, file, ".json");

        const json: std.json.Parsed(std.json.Value) = try std.json.parseFromSlice(std.json.Value, self.allocator.*, content, .{ .allocate = .alloc_always, .duplicate_field_behavior = .@"error", .ignore_unknown_fields = true, .parse_numbers = true });

        return json;
    }

    fn get(self: *JSONRegistry, id: NamespacedId) ?*std.json.Value {
        if(self.loaded.getPtr(id)) |ptr| {
            return &ptr.value;
        }

        if(self.entries.get(id)) |file| {
            const registry = self.load(id, file) catch return null;

            self.loaded.put(id, registry) catch return null;

            return &self.loaded.getPtr(id).?.value;
        }

        return null;
    }

    fn deinit(self: *JSONRegistry) void {
        self.loaded.deinit();
        self.entries.deinit();
        freeFoundFiles(self.files, self.allocator);
        self.allocator.destroy(self);
    }
    
    pub fn asRegistry(self: *JSONRegistry) RegistryBase {
        return .{ .ptr = @ptrCast(self), .vtable = .{
            .list = @ptrCast(&list),
            .deinit = @ptrCast(&deinit),
            .get = @ptrCast(&get),
        }};
    }
};

const RegistryRegistryHashMap = std.HashMap(NamespacedId, RegistryBase, NamespacedId.Context, std.hash_map.default_max_load_percentage);

pub const RegistryRegistry = struct {
    entries: RegistryHashMap,
    loaded: RegistryRegistryHashMap,
    allocator: *const std.mem.Allocator,

    files: []RegistryFile,
    
    pub fn init(allocator: *const std.mem.Allocator) RegistryError!*RegistryRegistry {
        const self = allocator.create(RegistryRegistry) catch return RegistryError.allocation_error;
        errdefer allocator.destroy(self);
        self.allocator = allocator;

        self.entries = RegistryHashMap.init(allocator.*);
        errdefer self.entries.deinit();

        self.loaded = RegistryRegistryHashMap.init(allocator.*);
        errdefer self.loaded.deinit();

        self.loaded.put(.{ .namespace = "engine", .id="registry" }, self.asRegistry()) catch return RegistryError.allocation_error;
        self.entries.put(.{ .namespace = "engine", .id="registry"}, .{.namespace = "engine", .path = "registry", .root = .builtin}) catch return RegistryError.allocation_error;

        self.files = findFiles("registry", allocator, ".json") catch return RegistryError.allocation_error;
        for(self.files) |file| {
            self.entries.put(.{.namespace = file.namespace, .id= file.path}, file) catch return RegistryError.allocation_error;
        }
        
        return self;
    }

    pub fn load(self: *const RegistryRegistry, id: NamespacedId, file: RegistryFile) !RegistryBase {
        const content = try RegistryBase.load(self.allocator, id, "registry", file, ".json");
        const json: std.json.Parsed(RegistryInfo) = try std.json.parseFromSlice(RegistryInfo, self.allocator.*, content, .{ .allocate = .alloc_always, .duplicate_field_behavior = .@"error", .ignore_unknown_fields = true, .parse_numbers = true });
        defer json.deinit();

        return switch(json.value.type) {
            .json => try JSONRegistry.init(self.allocator, json.value.path),
        }.asRegistry();
    } 

    fn list(self: *const RegistryRegistry) RegistryError!RegistryHashMap.KeyIterator {
        return self.entries.keyIterator();
    }

    pub fn get(self: *RegistryRegistry, id: NamespacedId) ?*RegistryBase {
        if(self.loaded.getPtr(id)) |ptr| {
            return ptr;
        }

        if(self.entries.get(id)) |file| {
            const registry = self.load(id, file) catch return null;

            self.loaded.put(id, registry) catch return null;

            return self.loaded.getPtr(id).?;
        }

        return null;
    }

    pub fn deinit(self: *RegistryRegistry) void {
        self.entries.deinit();
        self.loaded.deinit();
        freeFoundFiles(self.files, self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asRegistry(self: *RegistryRegistry) RegistryBase {
        return .{ .ptr = @ptrCast(self), .vtable = .{ 
            .list = @ptrCast(&list),
            .get = @ptrCast(&get), 
            .deinit = @ptrCast(&deinit),
        }};
    }
};

pub const RegistryBase = struct {
    ptr: *anyopaque,
    vtable: VTable,

    pub const VTable = struct {
        list: *const fn (*const anyopaque) RegistryError!RegistryHashMap.KeyIterator,
        deinit: *const fn (*anyopaque) void,
        get: *const fn (*anyopaque, NamespacedId) ?*anyopaque,
    };

    pub fn list(self: *const RegistryBase) RegistryError!RegistryHashMap.KeyIterator {
        return self.vtable.list(self.ptr);
    }

    pub fn getParse(self: *const RegistryBase, id: []const u8, allocator: *std.mem.Allocator, comptime T: type) ?*T {
        const namespacedId = try NamespacedId.parse(id, allocator);
        defer namespacedId.deinit();

        const result = self.vtable.get(self.ptr, namespacedId);
        
        return @alignCast(@ptrCast(result));
    }

    pub fn get(self: *RegistryBase, id: NamespacedId, comptime T: type) ?*T {
        const result = self.vtable.get(self.ptr, id);
        
        return @alignCast(@ptrCast(result));
    }

    pub fn deinit(self: *const RegistryBase) void {
        self.vtable.deinit(self.ptr);
    }

    fn load(allocator: *const std.mem.Allocator, id: NamespacedId, registry: []const u8, file: RegistryFile, file_ext: []const u8) ![]u8 {
        const filePath = try allocator.alloc(u8, file.path.len + file_ext.len);
        @memcpy(filePath[0..file.path.len], file.path);
        @memcpy(filePath[file.path.len..], file_ext);

        const path = switch(file.root) {
            .root => try std.fs.path.join(allocator.*, &.{"app", id.namespace, registry, filePath}),
            .mod => |modname| try std.fs.path.join(allocator.*, &.{"mods", modname, id.namespace, registry, filePath}),
            .builtin => @panic("Attempted to load builtin registry file!"),
        };
        defer allocator.free(path);

        std.log.debug("Path: {s}", .{path});

        const f = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
        defer f.close();

        var read_buf: [1024]u8 = undefined;
        var file_reader = f.reader(&read_buf);
        const reader = &file_reader.interface; // <── Important!

        var content = std.Io.Writer.Allocating.init(allocator.*);
        defer content.deinit();

        _ = try reader.streamRemaining(&content.writer);

        return try content.toOwnedSlice();
    } 
};

var registryRegistry: ?*RegistryRegistry = null;

pub fn init(allocator: *const std.mem.Allocator) RegistryError!void {
    registryRegistry = try RegistryRegistry.init(allocator);
}

pub fn getCoreRegistry(registry: []const u8) ?*RegistryBase {
    if(registryRegistry == null) {
        @panic("Registry was not initialized!");
    }

    const id: NamespacedId = .{ .namespace = "engine", .id = registry };

    return registryRegistry.?.get(id);
}

pub fn getRegistry(id: NamespacedId) ?*RegistryBase {
    if(registryRegistry == null) {
        @panic("Registry was not initialized!");
    }

    return registryRegistry.?.get(id);
}
