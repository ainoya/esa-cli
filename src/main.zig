const std = @import("std");
const esa_client = @import("esa_client.zig");

const Command = enum {
    team,
    search,
    get,
    category,
    tag,
    help,
};

const SearchOptions = struct {
    query: ?[]const u8 = null,
    page: usize = 1,
    per_page: usize = 20,
    sort: []const u8 = "updated",
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printHelp();
        return;
    }

    const command_str = args[1];
    const command = std.meta.stringToEnum(Command, command_str) orelse {
        std.debug.print("Unknown command: {s}\n", .{command_str});
        try printHelp();
        return;
    };

    // help command doesn't require authentication
    if (command == .help) {
        try printHelp();
        return;
    }

    // Get esa authentication credentials from environment variables
    const team = std.process.getEnvVarOwned(allocator, "ESA_TEAM") catch |err| {
        std.debug.print("Error: ESA_TEAM environment variable is not set.\n", .{});
        std.debug.print("Please set it with: export ESA_TEAM=your-team-name\n", .{});
        return err;
    };
    defer allocator.free(team);

    const access_token = std.process.getEnvVarOwned(allocator, "ESA_ACCESS_TOKEN") catch |err| {
        std.debug.print("Error: ESA_ACCESS_TOKEN environment variable is not set.\n", .{});
        std.debug.print("Please set it with: export ESA_ACCESS_TOKEN=your-access-token\n", .{});
        return err;
    };
    defer allocator.free(access_token);

    var client = esa_client.EsaClient.init(allocator, team, access_token);
    defer client.deinit();

    switch (command) {
        .team => {
            const response = try client.getTeamInfo();
            defer allocator.free(response);
            try client.printTeamInfo(response);
        },
        .search => {
            if (args.len < 3) {
                std.debug.print("Usage: {s} search <query> [options]\n", .{args[0]});
                std.debug.print("Options:\n", .{});
                std.debug.print("  --page=1           Page number (default: 1)\n", .{});
                std.debug.print("  --per-page=20      Number of results per page (default: 20)\n", .{});
                std.debug.print("  --sort=updated     Sort order: updated, created, stars, watches, comments, best_match (default: updated)\n", .{});
                std.debug.print("\nQuery filters:\n", .{});
                std.debug.print("  category:<name>    Filter by category\n", .{});
                std.debug.print("  tag:<name>         Filter by tag\n", .{});
                std.debug.print("  user:<name>        Filter by user\n", .{});
                std.debug.print("  kind:<type>        Filter by kind (stock, flow)\n", .{});
                std.debug.print("\nExamples:\n", .{});
                std.debug.print("  {s} search \"API documentation\"\n", .{args[0]});
                std.debug.print("  {s} search \"category:dev/api\"\n", .{args[0]});
                std.debug.print("  {s} search \"tag:important\" --sort=stars\n", .{args[0]});
                return;
            }

            var options = SearchOptions{ .query = args[2] };

            // Parse options
            var i: usize = 3;
            while (i < args.len) : (i += 1) {
                const arg = args[i];
                if (std.mem.startsWith(u8, arg, "--page=")) {
                    options.page = std.fmt.parseInt(usize, arg[7..], 10) catch 1;
                } else if (std.mem.startsWith(u8, arg, "--per-page=")) {
                    options.per_page = std.fmt.parseInt(usize, arg[11..], 10) catch 20;
                } else if (std.mem.startsWith(u8, arg, "--sort=")) {
                    options.sort = arg[7..];
                }
            }

            const response = try client.searchPosts(options.query, options.page, options.per_page, options.sort);
            defer allocator.free(response);
            try client.printSearchResults(response);
        },
        .get => {
            if (args.len < 3) {
                std.debug.print("Usage: {s} get <post-number>\n", .{args[0]});
                std.debug.print("\nExample:\n", .{});
                std.debug.print("  {s} get 123\n", .{args[0]});
                return;
            }

            const post_number = try std.fmt.parseInt(u32, args[2], 10);
            const response = try client.getPost(post_number);
            defer allocator.free(response);
            try client.printPostDetail(response);
        },
        .category => {
            if (args.len < 3) {
                std.debug.print("Usage: {s} category <category-name> [options]\n", .{args[0]});
                std.debug.print("Options:\n", .{});
                std.debug.print("  --page=1           Page number (default: 1)\n", .{});
                std.debug.print("  --per-page=20      Number of results per page (default: 20)\n", .{});
                std.debug.print("  --sort=updated     Sort order (default: updated)\n", .{});
                std.debug.print("\nExample:\n", .{});
                std.debug.print("  {s} category \"dev/api\"\n", .{args[0]});
                return;
            }

            var page: usize = 1;
            var per_page: usize = 20;
            var sort: []const u8 = "updated";

            // Parse options
            var i: usize = 3;
            while (i < args.len) : (i += 1) {
                const arg = args[i];
                if (std.mem.startsWith(u8, arg, "--page=")) {
                    page = std.fmt.parseInt(usize, arg[7..], 10) catch 1;
                } else if (std.mem.startsWith(u8, arg, "--per-page=")) {
                    per_page = std.fmt.parseInt(usize, arg[11..], 10) catch 20;
                } else if (std.mem.startsWith(u8, arg, "--sort=")) {
                    sort = arg[7..];
                }
            }

            const response = try client.getPostsByCategory(args[2], page, per_page, sort);
            defer allocator.free(response);
            try client.printSearchResults(response);
        },
        .tag => {
            if (args.len < 3) {
                std.debug.print("Usage: {s} tag <tag-name> [options]\n", .{args[0]});
                std.debug.print("Options:\n", .{});
                std.debug.print("  --page=1           Page number (default: 1)\n", .{});
                std.debug.print("  --per-page=20      Number of results per page (default: 20)\n", .{});
                std.debug.print("  --sort=updated     Sort order (default: updated)\n", .{});
                std.debug.print("\nExample:\n", .{});
                std.debug.print("  {s} tag \"important\"\n", .{args[0]});
                return;
            }

            var page: usize = 1;
            var per_page: usize = 20;
            var sort: []const u8 = "updated";

            // Parse options
            var i: usize = 3;
            while (i < args.len) : (i += 1) {
                const arg = args[i];
                if (std.mem.startsWith(u8, arg, "--page=")) {
                    page = std.fmt.parseInt(usize, arg[7..], 10) catch 1;
                } else if (std.mem.startsWith(u8, arg, "--per-page=")) {
                    per_page = std.fmt.parseInt(usize, arg[11..], 10) catch 20;
                } else if (std.mem.startsWith(u8, arg, "--sort=")) {
                    sort = arg[7..];
                }
            }

            const response = try client.getPostsByTag(args[2], page, per_page, sort);
            defer allocator.free(response);
            try client.printSearchResults(response);
        },
        .help => {
            try printHelp();
        },
    }
}

fn printHelp() !void {
    std.debug.print(
        \\esa CLI Tool
        \\
        \\Usage:
        \\  esa-cli <command> [arguments] [options]
        \\
        \\Commands:
        \\  team                 Get team information
        \\  search <query>       Search posts across the team
        \\  get <number>         Get a specific post by number
        \\  category <name>      Get posts in a specific category
        \\  tag <name>           Get posts with a specific tag
        \\  help                 Show this help message
        \\
        \\Environment Variables:
        \\  ESA_TEAM             Your esa team name (required)
        \\  ESA_ACCESS_TOKEN     Your esa access token (required)
        \\
        \\Examples:
        \\  esa-cli team
        \\  esa-cli search "API documentation"
        \\  esa-cli search "category:dev/api tag:important"
        \\  esa-cli get 123
        \\  esa-cli category "dev/api"
        \\  esa-cli tag "important"
        \\
        \\For detailed usage of each command, run:
        \\  esa-cli <command>
        \\
        \\
    , .{});
}
