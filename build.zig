const std = @import("std");

fn initNativeLibrary(lib: *std.Build.Step.Compile, tvg: *std.Build.Module) void {
    lib.root_module.addImport("tvg", tvg);
    lib.addIncludePath(lib.step.owner.path("src/binding/include"));
    lib.bundle_compiler_rt = true;
}

pub fn build(b: *std.Build) !void {
    const ptk_dep = b.dependency("ptk", .{});
    const ptk = ptk_dep.module("parser-toolkit");

    // TinyVG package
    const tvg = b.addModule("tvg", .{
        .root_source_file = b.path("src/lib/tinyvg.zig"),
        .imports = &.{ .{ .name = "ptk", .module = ptk }},
    });

    const args_dep = b.dependency("args", .{});
    const args = args_dep.module("args");
    const www_folder = std.Build.InstallDir{ .custom = "www" };

    const install_include = b.option(bool, "install-include", "Installs the include directory") orelse true;
    const install_www = b.option(bool, "install-www", "Installs the www directory (polyfill)") orelse true;
    const install_lib = b.option(bool, "install-lib", "Installs the lib directory") orelse true;
    const install_bin = b.option(bool, "install-bin", "Installs the bin directory") orelse true;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const static_native_lib = b.addStaticLibrary(.{
        .name = "tinyvg",
        .root_source_file = b.path("src/binding/binding.zig"),
        .target = target,
        .optimize = optimize,
    });
    initNativeLibrary(static_native_lib, tvg);
    if (install_lib) {
        b.installArtifact(static_native_lib);
    }

    const dynamic_lib_name = if (target.result.os.tag == .windows)
        "tinyvg.dll"
    else
        "tinyvg";

    const dynamic_native_lib = b.addSharedLibrary(.{
        .name = dynamic_lib_name,
        .root_source_file = b.path("src/binding/binding.zig"),
        .target = target,
        .optimize = optimize,
    });
    initNativeLibrary(dynamic_native_lib, tvg);
    if (install_lib) {
        b.installArtifact(dynamic_native_lib);
    }

    if (install_include) {
        const install_header = b.addInstallFileWithDir(b.path("src/binding/include/tinyvg.h"), .header, "tinyvg.h");
        b.getInstallStep().dependOn(&install_header.step);
    }

    const render = b.addExecutable(.{
        .name = "tvg-render",
        .root_source_file = b.path("src/tools/render.zig"),
        .target = target,
        .optimize = optimize,
    });
    render.root_module.addImport("tvg", tvg);
    render.root_module.addImport("args", args);
    if (install_bin) {
        b.installArtifact(render);
    }

    const text = b.addExecutable(.{
        .name = "tvg-text",
        .root_source_file = b.path("src/tools/text.zig"),
        .target = target,
        .optimize = optimize,
    });
    text.root_module.addImport("tvg", tvg);
    text.root_module.addImport("args", args);
    text.root_module.addImport("ptk", ptk);
    if (install_bin) {
        b.installArtifact(text);
    }

    const ground_truth_generator = b.addExecutable(.{
        .name = "ground-truth-generator",
        .root_source_file = b.path("src/lib/ground-truth.zig"),
        .target = b.host,
        .optimize = optimize,
    });
    for (tvg.import_table.keys(), tvg.import_table.values()) |name, mod| {
        ground_truth_generator.root_module.addImport(name, mod);
    }

    const generate_ground_truth = b.addRunArtifact(ground_truth_generator);
    generate_ground_truth.cwd = .{ .cwd_relative = b.cache_root.path.? };

    const gen_gt_step = b.step("generate", "Regenerates the ground truth data.");

    const files = [_][]const u8{
        "shield-16.tvg",  "shield-8.tvg",      "shield-32.tvg",
        "everything.tvg", "everything-32.tvg",
    };
    inline for (files) |file| {
        const tvg_conversion = b.addRunArtifact(render);
        tvg_conversion.addArg(file);
        tvg_conversion.addArg("--super-sampling");
        tvg_conversion.addArg("2");
        tvg_conversion.addArg("--output");
        tvg_conversion.addArg(file[0 .. file.len - 3] ++ "tga");
        tvg_conversion.cwd = .{ .cwd_relative = b.cache_root.path.? };
        tvg_conversion.step.dependOn(&generate_ground_truth.step);

        const tvgt_conversion = b.addRunArtifact(text);
        tvgt_conversion.addArg(file);
        tvgt_conversion.addArg("--output");
        tvgt_conversion.addArg(file[0 .. file.len - 3] ++ "tvgt");
        tvgt_conversion.cwd = .{ .cwd_relative = b.cache_root.path.? };
        tvgt_conversion.step.dependOn(&generate_ground_truth.step);

        gen_gt_step.dependOn(&tvgt_conversion.step);
        gen_gt_step.dependOn(&tvg_conversion.step);
    }

    {
        const tvg_tests = b.addTest(.{
            .root_source_file = tvg.root_source_file.?,
            .optimize = optimize,
        });
        for (tvg.import_table.keys(), tvg.import_table.values()) |name, mod| {
            tvg_tests.root_module.addImport(name, mod);
        }

        const static_binding_test = b.addExecutable(.{
            .name = "static-native-binding",
            .target = target,
            .optimize = optimize,
        });
        static_binding_test.linkLibC();
        static_binding_test.addIncludePath(b.path("src/binding/include"));
        static_binding_test.addCSourceFile(.{
            .file = b.path("examples/usage.c"),
            .flags = &[_][]const u8{ "-Wall", "-Wextra", "-pedantic", "-std=c99" },
        });
        static_binding_test.linkLibrary(static_native_lib);

        const dynamic_binding_test = b.addExecutable(.{
            .name = "dynamic-native-binding",
            .optimize = optimize,
            .target = target,
        });
        dynamic_binding_test.linkLibC();
        dynamic_binding_test.addIncludePath(b.path("src/binding/include"));
        dynamic_binding_test.addCSourceFile(.{ .file = b.path("examples/usage.c"), .flags = &[_][]const u8{ "-Wall", "-Wextra", "-pedantic", "-std=c99" } });
        dynamic_binding_test.linkLibrary(dynamic_native_lib);

        const static_binding_test_run = b.addRunArtifact(static_binding_test);
        static_binding_test_run.cwd = .{ .cwd_relative = b.cache_root.path.? };

        const dynamic_binding_test_run = b.addRunArtifact(dynamic_binding_test);
        dynamic_binding_test_run.cwd = .{ .cwd_relative = b.cache_root.path.? };

        const test_step = b.step("test", "Runs all tests");
        test_step.dependOn(&b.addRunArtifact(tvg_tests).step);
        test_step.dependOn(&static_binding_test_run.step);
        test_step.dependOn(&dynamic_binding_test_run.step);
    }

    const polyfill = b.addExecutable(.{
        .name = "tinyvg",
        .root_source_file = b.path("src/polyfill/tinyvg.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .cpu_model = .baseline,
            .os_tag = .freestanding,
        }),
        .optimize = optimize,
    });
    polyfill.entry = .disabled;
    polyfill.root_module.export_symbol_names = &.{ "convertToSvg" };
    polyfill.root_module.strip = (optimize != .Debug);
    polyfill.root_module.addImport("tvg", tvg);

    if (install_www) {
        var artifact_install = b.addInstallArtifact(polyfill, .{});
        artifact_install.dest_dir = www_folder;
        b.getInstallStep().dependOn(&artifact_install.step);
    }

    const copy_stuff = b.addInstallFileWithDir(b.path("src/polyfill/tinyvg.js"), www_folder, "tinyvg.js");

    if (install_www) {
        b.getInstallStep().dependOn(&copy_stuff.step);
    }
}
