const std = @import("std");

const pkgs = struct {
    // TinyVG package
    const tvg = std.build.Pkg{
        .name = "tvg",
        .path = .{ .path = "src/lib/tinyvg.zig" },
        .dependencies = &.{ptk},
    };
    const ptk = std.build.Pkg{
        .name = "ptk",
        .path = .{ .path = "vendor/parser-toolkit/src/main.zig" },
    };

    const args = std.build.Pkg{
        .name = "args",
        .path = .{ .path = "vendor/zig-args/args.zig" },
    };
};

fn initNativeLibrary(lib: *std.build.LibExeObjStep, mode: std.builtin.Mode, target: std.zig.CrossTarget) void {
    lib.addPackage(pkgs.tvg);
    lib.addIncludeDir("src/binding/include");
    lib.setBuildMode(mode);
    lib.setTarget(target);
    lib.bundle_compiler_rt = true;
}

pub fn build(b: *std.build.Builder) !void {
    const www_folder = std.build.InstallDir{ .custom = "www" };

    const is_release = b.option(bool, "release", "Prepares a release build") orelse false;
    const enable_polyfill = b.option(bool, "polyfill", "Enables the polyfill build") orelse !is_release;
    const enable_poly_example = b.option(bool, "web-example", "Adds example files to the prefix/www folder for easier development") orelse (enable_polyfill and !is_release);

    const bundle_libs = b.option(bool, "libs", "Install the libs") orelse true;
    const bundle_headers = b.option(bool, "headers", "Install the headers") orelse true;
    const bundle_tools = b.option(bool, "tools", "Install the libs") orelse true;

    const target = b.standardTargetOptions(.{});
    const mode = if (is_release) .ReleaseSafe else b.standardReleaseOptions();

    const static_native_lib = b.addStaticLibrary("tinyvg", "src/binding/binding.zig");
    initNativeLibrary(static_native_lib, mode, target);
    if (bundle_libs) {
        static_native_lib.install();
    }

    const dynamic_native_lib = b.addSharedLibrary("tinyvg.dll", "src/binding/binding.zig", .unversioned);
    initNativeLibrary(dynamic_native_lib, mode, target);
    if (bundle_libs) {
        dynamic_native_lib.install();
    }

    if (bundle_headers) {
        const install_header = b.addInstallFileWithDir(.{ .path = "src/binding/include/tinyvg.h" }, .header, "tinyvg.h");
        b.getInstallStep().dependOn(&install_header.step);
    }

    const render = b.addExecutable("tvg-render", "src/tools/render.zig");
    render.setBuildMode(mode);
    render.setTarget(target);
    render.addPackage(pkgs.tvg);
    render.addPackage(pkgs.args);
    if (bundle_tools) {
        render.install();
    }

    const text = b.addExecutable("tvg-text", "src/tools/text.zig");
    text.setBuildMode(mode);
    text.setTarget(target);
    text.addPackage(pkgs.tvg);
    text.addPackage(pkgs.args);
    text.addPackage(pkgs.ptk);
    if (bundle_tools) {
        text.install();
    }

    const ground_truth_generator = b.addExecutable("ground-truth-generator", "src/data/ground-truth.zig");
    ground_truth_generator.setBuildMode(mode);
    ground_truth_generator.addPackage(pkgs.tvg);

    const generate_ground_truth = ground_truth_generator.run();
    generate_ground_truth.cwd = "examples/tinyvg";

    const gen_gt_step = b.step("generate", "Regenerates the ground truth data.");
    gen_gt_step.dependOn(&generate_ground_truth.step);

    const files = [_][]const u8{
        // "app_menu.tvg",  "workspace.tvg", "workspace_add.tvg", "feature-showcase.tvg", "arc-variants.tvg", ,
        "shield-16.tvg",  "shield-8.tvg",      "shield-32.tvg",
        "everything.tvg", "everything-32.tvg",
    };
    inline for (files) |file| {
        const tvg_conversion = render.run();
        tvg_conversion.addArg(file);
        tvg_conversion.addArg("--super-sampling");
        tvg_conversion.addArg("4"); // 16 times multisampling
        tvg_conversion.addArg("--output");
        tvg_conversion.addArg(file[0 .. file.len - 3] ++ "tga");
        tvg_conversion.cwd = "examples/tinyvg";

        const tvgt_conversion = text.run();
        tvgt_conversion.addArg(file);
        tvgt_conversion.addArg("--output");
        tvgt_conversion.addArg(file[0 .. file.len - 3] ++ "tvgt");
        tvgt_conversion.cwd = "examples/tinyvg";

        const png_conversion = b.addSystemCommand(&[_][]const u8{
            "convert",
            "-strip",
            file[0 .. file.len - 3] ++ "tga",
            file[0 .. file.len - 3] ++ "png",
        });
        png_conversion.cwd = "examples/tinyvg";
        png_conversion.step.dependOn(&tvg_conversion.step);

        gen_gt_step.dependOn(&tvgt_conversion.step);
        gen_gt_step.dependOn(&png_conversion.step);
    }
    {
        const tvg_tests = b.addTestSource(pkgs.tvg.path);
        for (pkgs.tvg.dependencies.?) |dep| {
            tvg_tests.addPackage(dep);
        }

        tvg_tests.addPackage(std.build.Pkg{
            .name = "ground-truth",
            .path = .{ .path = "src/data/ground-truth.zig" },
            .dependencies = &[_]std.build.Pkg{
                pkgs.tvg,
            },
        });

        const static_binding_test = b.addExecutable("static-native-binding", null);
        static_binding_test.setBuildMode(mode);
        static_binding_test.linkLibC();
        static_binding_test.addIncludeDir("src/binding/include");
        static_binding_test.addCSourceFile("examples/native/usage.c", &[_][]const u8{ "-Wall", "-Wextra", "-pedantic", "-std=c99" });
        static_binding_test.linkLibrary(static_native_lib);

        const dynamic_binding_test = b.addExecutable("static-native-binding", null);
        dynamic_binding_test.setBuildMode(mode);
        dynamic_binding_test.linkLibC();
        dynamic_binding_test.addIncludeDir("src/binding/include");
        dynamic_binding_test.addCSourceFile("examples/native/usage.c", &[_][]const u8{ "-Wall", "-Wextra", "-pedantic", "-std=c99" });
        dynamic_binding_test.linkLibrary(dynamic_native_lib);

        const static_binding_test_run = static_binding_test.run();
        static_binding_test_run.cwd = "zig-cache";

        const dynamic_binding_test_run = dynamic_binding_test.run();
        dynamic_binding_test_run.cwd = "zig-cache";

        const test_step = b.step("test", "Runs all tests");
        test_step.dependOn(&tvg_tests.step);
        test_step.dependOn(&static_binding_test_run.step);
        if (!is_release) {
            // workaround for https://github.com/ziglang/zig/pull/10347/files
            test_step.dependOn(&dynamic_binding_test_run.step);
        }
    }
    {
        const merge_covs = b.addSystemCommand(&[_][]const u8{
            "kcov",
            "--merge",
            b.pathFromRoot("kcov-output"),
            b.pathFromRoot("kcov-output"),
        });
        inline for (files) |file| {
            merge_covs.addArg(b.pathJoin(&[_][]const u8{ b.pathFromRoot("kcov-output"), file }));
        }

        const tvg_coverage = b.addTest("src/lib/tvg.zig");
        tvg_coverage.addPackage(std.build.Pkg{
            .name = "ground-truth",
            .path = .{ .path = "src/data/ground-truth.zig" },
            .dependencies = &[_]std.build.Pkg{
                pkgs.tvg,
            },
        });
        tvg_coverage.setExecCmd(&[_]?[]const u8{
            "kcov",
            "--exclude-path=~/software/zig-current",
            b.pathFromRoot("kcov-output"), // output dir for kcov
            null, // to get zig to use the --test-cmd-bin flag
        });

        const generator_coverage = b.addSystemCommand(&[_][]const u8{
            "kcov",
            "--exclude-path=~/software/zig-current",
            b.pathFromRoot("kcov-output"), // output dir for kcov
        });
        generator_coverage.addArtifactArg(ground_truth_generator);

        inline for (files) |file| {
            const tvg_conversion = b.addSystemCommand(&[_][]const u8{
                "kcov",
                "--exclude-path=~/software/zig-current",
                b.pathJoin(&[_][]const u8{ b.pathFromRoot("kcov-output"), file }), // output dir for kcov
            });
            tvg_conversion.addArtifactArg(render);
            tvg_conversion.addArg(file);
            tvg_conversion.addArg("--output");
            tvg_conversion.addArg(file[0 .. file.len - 3] ++ "tga");
            tvg_conversion.cwd = "examples/tinyvg";

            merge_covs.step.dependOn(&tvg_conversion.step);
        }

        merge_covs.step.dependOn(&tvg_coverage.step);
        merge_covs.step.dependOn(&generator_coverage.step);

        const coverage_step = b.step("coverage", "Generates ground truth and runs all tests with kcov");
        coverage_step.dependOn(&merge_covs.step);
    }

    // web stuff
    if (enable_polyfill) {
        const polyfill = b.addSharedLibrary("tinyvg", "src/polyfill/tinyvg.zig", .unversioned);
        if (is_release) {
            polyfill.setBuildMode(.ReleaseSmall);
            polyfill.strip = true;
        } else {
            polyfill.setBuildMode(mode);
        }
        polyfill.setTarget(.{
            .cpu_arch = .wasm32,
            .cpu_model = .baseline,
            .os_tag = .freestanding,
        });
        polyfill.addPackage(pkgs.tvg);

        polyfill.install();
        polyfill.install_step.?.dest_dir = www_folder;

        if (enable_polyfill) {
            const release_files = [_][]const u8{
                "src/polyfill/tinyvg.js",
            };
            const debug_files = [_][]const u8{
                "examples/web/index.htm",
                "examples/tinyvg/shield-16.tvg",
                "examples/tinyvg/everything-32.tvg",
                "src/polyfill/tinyvg.js",
            };

            const web_example_files = if (enable_poly_example)
                &debug_files
            else
                &release_files;

            for (web_example_files) |src_path| {
                const copy_stuff = b.addInstallFileWithDir(.{ .path = src_path }, www_folder, std.fs.path.basename(src_path));
                if (target.isNative() and enable_poly_example) {
                    copy_stuff.step.dependOn(gen_gt_step);
                }
                b.getInstallStep().dependOn(&copy_stuff.step);
            }
        }
    }
}
