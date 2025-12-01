# esa-cli

Command-line interface tool for esa.io API. Implemented in Zig.

## Features

- Get team information
- Search posts (by keywords, category, tags, users, etc.)
- Get specific posts
- Get posts by category
- Get posts by tag

## Prerequisites

- Zig 0.13.0 or later
- esa access token

## Installation

### Clone the repository

```bash
git clone <repository-url>
cd esa-cli
```

### Build

```bash
zig build
```

### Local installation (optional)

To install to `~/.local/bin`:

```bash
zig build install-local
```

This makes the `esa-cli` command available system-wide (if `~/.local/bin` is in your PATH).

## Configuration

You need to set environment variables:

```bash
export ESA_TEAM=your-team-name
export ESA_ACCESS_TOKEN=your-access-token
```

### How to get an access token

1. Visit `https://[your-team].esa.io/user/applications`
2. Click "Generate new token"
3. Select appropriate scopes (at least `read` permission is required)
4. Generate and copy the token

### Persistent configuration

Add to `.bashrc`, `.zshrc`, or `.profile`:

```bash
export ESA_TEAM=your-team-name
export ESA_ACCESS_TOKEN=your-access-token
```

Or, use `.envrc` (with direnv):

```bash
export ESA_TEAM=your-team-name
export ESA_ACCESS_TOKEN=your-access-token
```

## Usage

### Get team information

```bash
esa-cli team
```

### Search posts

Basic search:

```bash
esa-cli search "API documentation"
```

Search with filters:

```bash
# Filter by category
esa-cli search "category:dev/api"

# Filter by tag
esa-cli search "tag:important"

# Combine multiple filters
esa-cli search "category:dev/api tag:important"

# Filter by user
esa-cli search "user:username"

# Filter by post kind
esa-cli search "kind:stock"
```

Options:

```bash
# Pagination
esa-cli search "API" --page=2 --per-page=10

# Change sort order
esa-cli search "API" --sort=stars
# Available sort options: updated, created, stars, watches, comments, best_match
```

### Get a specific post

```bash
esa-cli get 123
```

### Get posts by category

```bash
esa-cli category "dev/api"
esa-cli category "dev/api" --page=2 --per-page=10 --sort=created
```

### Get posts by tag

```bash
esa-cli tag "important"
esa-cli tag "important" --page=2 --per-page=10 --sort=stars
```

### Help

```bash
esa-cli help
```

Detailed help for each command:

```bash
esa-cli search
esa-cli get
esa-cli category
esa-cli tag
```

## Using with Claude Skills

This CLI tool is designed to be used as a Claude Skill.

### Setup

#### 1. Build and install the binary

```bash
cd esa-cli
zig build
```

The built binary will be located at `./zig-out/bin/esa-cli`.

To install globally:

```bash
zig build install-local
```

This installs to `~/.local/bin/esa-cli` (`~/.local/bin` must be in your PATH).

#### 2. Set environment variables

```bash
export ESA_TEAM=your-team-name
export ESA_ACCESS_TOKEN=your-access-token
```

For persistent configuration, add to `.bashrc`, `.zshrc`, or `.envrc` (with direnv).

#### 3. Enable Claude Skill

This repository includes a Claude Skill definition at `.claude/skills/esa/skill.md`.

Claude Code automatically detects and makes this skill available. To use the skill, instruct Claude like:

```
Search esa for posts about "API documentation"
```

Or

```
Get esa team information
```

### Skill features

The `esa` skill provides the following features:

- **Get team information**: Retrieve basic information about your esa team
- **Search posts**: Search by keywords, category, tags, users, etc.
- **Get specific post**: Retrieve full content by post number
- **Get posts by category**: Get list of posts in a specific category
- **Get posts by tag**: Get list of posts with a specific tag

See `.claude/skills/esa/skill.md` for detailed usage.

### Usage examples

The following operations are available through Claude Skills:

```bash
# Get team information
esa-cli team

# Search posts
esa-cli search "API documentation"

# Search by category
esa-cli search "category:dev/api"

# Get specific post
esa-cli get 123

# Get category posts
esa-cli category "dev/api"

# Get tagged posts
esa-cli tag "important"
```

### Natural language usage examples

By instructing Claude in natural language, it will execute the appropriate commands:

- "Search esa for API documentation"
- "Show me posts in the dev/api category on esa"
- "Tell me about post #123 on esa"
- "Find posts tagged with 'important'"

## Development

### Tests

```bash
zig build test
```

### Build options

```bash
# Debug build (default)
zig build

# Release build (optimized)
zig build -Doptimize=ReleaseFast

# Specify target
zig build -Dtarget=x86_64-macos
```

### Project structure

```
esa-cli/
├── .claude/
│   └── skills/
│       └── esa/
│           └── skill.md       # Claude Skill definition
├── build.zig                  # Build configuration
├── build.zig.zon              # Package metadata
├── .gitignore                 # Git exclusions
├── .envrc.example             # Environment variable example
├── src/
│   ├── main.zig               # Main entry point
│   ├── esa_client.zig         # esa API client
│   └── root.zig               # Module entry point
└── README.md                  # This file
```

## Troubleshooting

### "ESA_TEAM environment variable is not set"

The `ESA_TEAM` environment variable is not set. Please refer to the "Configuration" section above.

### "ESA_ACCESS_TOKEN environment variable is not set"

The `ESA_ACCESS_TOKEN` environment variable is not set. Please refer to the "Configuration" section above.

### "esa API HTTP Error"

- Verify your access token is valid
- Verify your team name is correct
- Verify your token has appropriate permissions

## License

MIT License

## References

- [esa API Documentation](https://docs.esa.io/posts/102)
- [Zig Official Website](https://ziglang.org/)
