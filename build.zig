const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("esa_cli", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "esa-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "esa_cli", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Custom install step to install the binary to ~/.local/bin
    const install_local_step = b.step("install-local", "Install the binary to ~/.local/bin");

    const home_dir = std.posix.getenv("HOME") orelse {
        std.debug.print("HOME environment variable not set\n", .{});
        return;
    };

    const install_dir = b.fmt("{s}/.local/bin", .{home_dir});
    const install_path = b.fmt("{s}/esa-cli", .{install_dir});

    const mkdir_cmd = b.addSystemCommand(&[_][]const u8{ "mkdir", "-p", install_dir });

    const cp_cmd = b.addSystemCommand(&[_][]const u8{
        "cp",
        b.getInstallPath(.bin, "esa-cli"),
        install_path,
    });
    cp_cmd.step.dependOn(&mkdir_cmd.step);
    cp_cmd.step.dependOn(b.getInstallStep());

    install_local_step.dependOn(&cp_cmd.step);
}
