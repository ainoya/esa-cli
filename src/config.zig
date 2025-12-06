const std = @import("std");

pub const Config = struct {
    esa_team: ?[]const u8 = null,

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        if (self.esa_team) |t| allocator.free(t);
    }
};

pub const SecretConfig = struct {
    esa_access_token: ?[]const u8 = null,

    pub fn deinit(self: *SecretConfig, allocator: std.mem.Allocator) void {
        if (self.esa_access_token) |t| allocator.free(t);
    }
};

pub const ConfigManager = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ConfigManager {
        return ConfigManager{ .allocator = allocator };
    }

    fn getConfigPath(self: ConfigManager, filename: []const u8) ![]u8 {
        var env_map = try std.process.getEnvMap(self.allocator);
        defer env_map.deinit();

        const home = env_map.get("HOME") orelse env_map.get("USERPROFILE") orelse return error.HomeNotFound;
        return std.fs.path.join(self.allocator, &[_][]const u8{ home, ".config", "esa-cli", filename });
    }

    pub fn loadConfig(self: ConfigManager) !Config {
        const path = try self.getConfigPath("config.json");
        defer self.allocator.free(path);

        const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return Config{};
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        if (content.len == 0) return Config{};

        const parsed = try std.json.parseFromSlice(Config, self.allocator, content, .{ .ignore_unknown_fields = true });

        var config = Config{};
        if (parsed.value.esa_team) |t| config.esa_team = try self.allocator.dupe(u8, t);

        parsed.deinit();
        return config;
    }

    pub fn loadSecret(self: ConfigManager) !SecretConfig {
        const path = try self.getConfigPath("secret.json");
        defer self.allocator.free(path);

        const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return SecretConfig{};
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        if (content.len == 0) return SecretConfig{};

        const parsed = try std.json.parseFromSlice(SecretConfig, self.allocator, content, .{ .ignore_unknown_fields = true });

        var config = SecretConfig{};
        if (parsed.value.esa_access_token) |t| config.esa_access_token = try self.allocator.dupe(u8, t);

        parsed.deinit();
        return config;
    }

    fn jsonEscape(val: []const u8, writer: anytype) !void {
        for (val) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                0x08 => try writer.writeAll("\\b"),
                0x0C => try writer.writeAll("\\f"),
                else => try writer.writeByte(c),
            }
        }
    }

    pub fn saveConfig(self: ConfigManager, config: Config) !void {
        const path = try self.getConfigPath("config.json");
        defer self.allocator.free(path);

        const dirname = std.fs.path.dirname(path) orelse return error.InvalidPath;
        try std.fs.cwd().makePath(dirname);

        const file = try std.fs.createFileAbsolute(path, .{ .mode = 0o600, .truncate = true });
        defer file.close();

        var list = std.ArrayListUnmanaged(u8){};
        defer list.deinit(self.allocator);

        const writer = list.writer(self.allocator);
        try writer.writeAll("{\n");
        if (config.esa_team) |t| {
            try writer.writeAll("  \"esa_team\": \"");
            try jsonEscape(t, writer);
            try writer.writeAll("\"\n");
        }
        try writer.writeAll("}\n");

        try file.writeAll(list.items);
    }

    pub fn saveSecret(self: ConfigManager, config: SecretConfig) !void {
        const path = try self.getConfigPath("secret.json");
        defer self.allocator.free(path);

        const dirname = std.fs.path.dirname(path) orelse return error.InvalidPath;
        try std.fs.cwd().makePath(dirname);

        const file = try std.fs.createFileAbsolute(path, .{ .mode = 0o600, .truncate = true });
        defer file.close();

        var list = std.ArrayListUnmanaged(u8){};
        defer list.deinit(self.allocator);

        const writer = list.writer(self.allocator);
        try writer.writeAll("{\n");
        if (config.esa_access_token) |t| {
            try writer.writeAll("  \"esa_access_token\": \"");
            try jsonEscape(t, writer);
            try writer.writeAll("\"\n");
        }
        try writer.writeAll("}\n");

        try file.writeAll(list.items);
    }

    pub fn set(self: ConfigManager, key: []const u8, value: []const u8) !void {
        if (std.mem.eql(u8, key, "esa_team")) {
            var config = try self.loadConfig();
            defer config.deinit(self.allocator);

            if (config.esa_team) |old| self.allocator.free(old);
            config.esa_team = try self.allocator.dupe(u8, value);

            try self.saveConfig(config);
        } else if (std.mem.eql(u8, key, "esa_access_token")) {
            var secret = try self.loadSecret();
            defer secret.deinit(self.allocator);

            if (secret.esa_access_token) |old| self.allocator.free(old);
            secret.esa_access_token = try self.allocator.dupe(u8, value);

            try self.saveSecret(secret);
        } else {
            return error.InvalidKey;
        }
    }

    pub fn get(self: ConfigManager, key: []const u8) !?[]u8 {
        if (std.mem.eql(u8, key, "esa_team")) {
            var config = try self.loadConfig();
            defer config.deinit(self.allocator);

            if (config.esa_team) |v| return try self.allocator.dupe(u8, v);
        } else if (std.mem.eql(u8, key, "esa_access_token")) {
            var secret = try self.loadSecret();
            defer secret.deinit(self.allocator);

            if (secret.esa_access_token) |v| return try self.allocator.dupe(u8, v);
        }
        return null;
    }
};
