const std = @import("std");

pub const EsaClient = struct {
    allocator: std.mem.Allocator,
    team: []const u8,
    access_token: []const u8,
    http_client: std.http.Client,

    pub fn init(allocator: std.mem.Allocator, team: []const u8, access_token: []const u8) EsaClient {
        return .{
            .allocator = allocator,
            .team = team,
            .access_token = access_token,
            .http_client = std.http.Client{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *EsaClient) void {
        self.http_client.deinit();
    }

    /// Send GET request to esa API
    fn makeGetRequest(self: *EsaClient, endpoint: []const u8, query_params: []const u8) ![]u8 {
        var url_buffer: [2048]u8 = undefined;
        const url = if (query_params.len > 0)
            try std.fmt.bufPrint(&url_buffer, "https://api.esa.io/v1/teams/{s}/{s}?{s}", .{ self.team, endpoint, query_params })
        else
            try std.fmt.bufPrint(&url_buffer, "https://api.esa.io/v1/teams/{s}/{s}", .{ self.team, endpoint });

        var auth_header_buffer: [512]u8 = undefined;
        const auth_header = try std.fmt.bufPrint(&auth_header_buffer, "Bearer {s}", .{self.access_token});

        var response_writer = std.io.Writer.Allocating.init(self.allocator);
        defer response_writer.deinit();

        const response = try self.http_client.fetch(.{
            .method = .GET,
            .location = .{ .url = url },
            .extra_headers = &[_]std.http.Header{
                .{ .name = "Authorization", .value = auth_header },
                .{ .name = "Content-Type", .value = "application/json" },
            },
            .response_writer = &response_writer.writer,
        });

        if (response.status != .ok) {
            std.debug.print("esa API HTTP Error: {}\n", .{response.status});
            return error.EsaApiError;
        }

        return try response_writer.toOwnedSlice();
    }

    /// Get team information
    pub fn getTeamInfo(self: *EsaClient) ![]u8 {
        return try self.makeGetRequest("", "");
    }

    /// Search posts
    pub fn searchPosts(self: *EsaClient, query: ?[]const u8, page: usize, per_page: usize, sort: []const u8) ![]u8 {
        var query_params_buffer: [2048]u8 = undefined;
        var query_params: []const u8 = "";

        if (query) |q| {
            // URL encode
            var encoded_query = try std.ArrayList(u8).initCapacity(self.allocator, q.len * 2);
            defer encoded_query.deinit(self.allocator);

            for (q) |c| {
                if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~' or c == ':') {
                    try encoded_query.append(self.allocator, c);
                } else if (c == ' ') {
                    try encoded_query.append(self.allocator, '+');
                } else {
                    try encoded_query.writer(self.allocator).print("%{X:0>2}", .{c});
                }
            }

            query_params = try std.fmt.bufPrint(
                &query_params_buffer,
                "q={s}&page={d}&per_page={d}&sort={s}",
                .{ encoded_query.items, page, per_page, sort },
            );
        } else {
            query_params = try std.fmt.bufPrint(
                &query_params_buffer,
                "page={d}&per_page={d}&sort={s}",
                .{ page, per_page, sort },
            );
        }

        return try self.makeGetRequest("posts", query_params);
    }

    /// Get post by post number
    pub fn getPost(self: *EsaClient, post_number: u32) ![]u8 {
        var endpoint_buffer: [256]u8 = undefined;
        const endpoint = try std.fmt.bufPrint(&endpoint_buffer, "posts/{d}", .{post_number});
        return try self.makeGetRequest(endpoint, "");
    }

    /// Search posts by category
    pub fn getPostsByCategory(self: *EsaClient, category: []const u8, page: usize, per_page: usize, sort: []const u8) ![]u8 {
        var query_buffer: [1024]u8 = undefined;
        const query = try std.fmt.bufPrint(&query_buffer, "category:{s}", .{category});
        return try self.searchPosts(query, page, per_page, sort);
    }

    /// Search posts by tag
    pub fn getPostsByTag(self: *EsaClient, tag: []const u8, page: usize, per_page: usize, sort: []const u8) ![]u8 {
        var query_buffer: [1024]u8 = undefined;
        const query = try std.fmt.bufPrint(&query_buffer, "tag:{s}", .{tag});
        return try self.searchPosts(query, page, per_page, sort);
    }

    /// Convert timestamp to human-readable format
    fn formatTimestamp(ts_str: []const u8, buffer: []u8) ![]const u8 {
        // Format ISO 8601 timestamp (e.g., "2024-01-01T12:00:00+09:00")
        // Simply use the first 19 characters (YYYY-MM-DDTHH:MM:SS)
        if (ts_str.len >= 19) {
            return std.fmt.bufPrint(buffer, "{s}", .{ts_str[0..19]});
        }
        return std.fmt.bufPrint(buffer, "{s}", .{ts_str});
    }

    /// Print search results
    pub fn printSearchResults(self: *EsaClient, response: []const u8) !void {
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        const root = parsed.value.object;

        const posts_array = root.get("posts");
        if (posts_array == null) {
            std.debug.print("No posts found.\n", .{});
            return;
        }

        const posts = posts_array.?.array;

        if (posts.items.len == 0) {
            std.debug.print("No posts found.\n", .{});
            return;
        }

        std.debug.print("\nFound {d} posts:\n", .{posts.items.len});
        std.debug.print("{s}\n", .{"=" ** 80});

        for (posts.items, 0..) |post, i| {
            const name = post.object.get("name") orelse continue;
            const full_name = post.object.get("full_name");
            const number = post.object.get("number");
            const url = post.object.get("url");

            std.debug.print("\n[{d}] #{d} {s}\n", .{ i + 1, number.?.integer, name.string });
            if (full_name) |fn_val| {
                std.debug.print("Full Name: {s}\n", .{fn_val.string});
            }

            if (post.object.get("updated_at")) |updated_at| {
                var ts_buffer: [64]u8 = undefined;
                const timestamp = formatTimestamp(updated_at.string, &ts_buffer) catch "unknown time";
                std.debug.print("Updated: {s}\n", .{timestamp});
            }

            if (url) |url_val| {
                std.debug.print("URL: {s}\n", .{url_val.string});
            }

            // Display category and tags
            if (post.object.get("category")) |category| {
                if (category != .null) {
                    std.debug.print("Category: {s}\n", .{category.string});
                }
            }

            if (post.object.get("tags")) |tags| {
                if (tags.array.items.len > 0) {
                    std.debug.print("Tags: ", .{});
                    for (tags.array.items, 0..) |tag, tag_idx| {
                        if (tag_idx > 0) std.debug.print(", ", .{});
                        std.debug.print("{s}", .{tag.string});
                    }
                    std.debug.print("\n", .{});
                }
            }
        }

        std.debug.print("\n{s}\n", .{"=" ** 80});

        // Display pagination information
        if (root.get("page")) |page| {
            const total_count = root.get("total_count");
            const per_page = root.get("per_page");
            std.debug.print("Page {d} (Total: {d} posts, {d} per page)\n", .{ page.integer, total_count.?.integer, per_page.?.integer });
        }
    }

    /// Print post detail
    pub fn printPostDetail(self: *EsaClient, response: []const u8) !void {
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        const post = parsed.value.object;

        const name = post.get("name") orelse return error.InvalidResponse;
        const number = post.get("number") orelse return error.InvalidResponse;
        const body_md = post.get("body_md");
        const url = post.get("url");

        std.debug.print("\n{s}\n", .{"=" ** 80});
        std.debug.print("Post #{d}: {s}\n", .{ number.integer, name.string });
        std.debug.print("{s}\n", .{"=" ** 80});

        if (post.get("full_name")) |full_name| {
            std.debug.print("\nFull Name: {s}\n", .{full_name.string});
        }

        if (post.get("category")) |category| {
            if (category != .null) {
                std.debug.print("Category: {s}\n", .{category.string});
            }
        }

        if (post.get("tags")) |tags| {
            if (tags.array.items.len > 0) {
                std.debug.print("Tags: ", .{});
                for (tags.array.items, 0..) |tag, i| {
                    if (i > 0) std.debug.print(", ", .{});
                    std.debug.print("{s}", .{tag.string});
                }
                std.debug.print("\n", .{});
            }
        }

        if (post.get("created_at")) |created_at| {
            var ts_buffer: [64]u8 = undefined;
            const timestamp = formatTimestamp(created_at.string, &ts_buffer) catch "unknown time";
            std.debug.print("Created: {s}\n", .{timestamp});
        }

        if (post.get("updated_at")) |updated_at| {
            var ts_buffer: [64]u8 = undefined;
            const timestamp = formatTimestamp(updated_at.string, &ts_buffer) catch "unknown time";
            std.debug.print("Updated: {s}\n", .{timestamp});
        }

        if (url) |url_val| {
            std.debug.print("URL: {s}\n", .{url_val.string});
        }

        if (body_md) |body| {
            std.debug.print("\n--- Body (Markdown) ---\n\n", .{});
            std.debug.print("{s}\n", .{body.string});
        }

        std.debug.print("\n{s}\n", .{"=" ** 80});
    }

    /// Print team information
    pub fn printTeamInfo(self: *EsaClient, response: []const u8) !void {
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        const team = parsed.value.object;

        std.debug.print("\n{s}\n", .{"=" ** 80});
        std.debug.print("Team Information\n", .{});
        std.debug.print("{s}\n", .{"=" ** 80});

        if (team.get("name")) |name| {
            std.debug.print("\nName: {s}\n", .{name.string});
        }

        if (team.get("privacy")) |privacy| {
            std.debug.print("Privacy: {s}\n", .{privacy.string});
        }

        if (team.get("description")) |description| {
            if (description != .null) {
                std.debug.print("Description: {s}\n", .{description.string});
            }
        }

        if (team.get("url")) |url| {
            std.debug.print("URL: {s}\n", .{url.string});
        }

        std.debug.print("\n{s}\n", .{"=" ** 80});
    }
};
