const std = @import("std");

const pkgs = struct {
    // TinyVG package
    const tvg = std.build.Pkg{
        .name = "tvg",
        .source = .{ .path = "src/lib/tinyvg.zig" },
        .dependencies = &.{ptk},
    };
    const ptk = std.build.Pkg{
        .name = "ptk",
        .source = .{ .path = "vendor/parser-toolkit/src/main.zig" },
    };

    const args = std.build.Pkg{
        .name = "args",
        .source = .{ .path = "vendor/zig-args/args.zig" },
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

    const install_include = b.option(bool, "install-include", "Installs the include directory") orelse true;
    const install_www = b.option(bool, "install-www", "Installs the www directory (polyfill)") orelse true;
    const install_lib = b.option(bool, "install-lib", "Installs the lib directory") orelse true;
    const install_bin = b.option(bool, "install-bin", "Installs the bin directory") orelse true;

    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const static_native_lib = b.addStaticLibrary("tinyvg", "src/binding/binding.zig");
    initNativeLibrary(static_native_lib, mode, target);
    if (install_lib) {
        static_native_lib.install();
    }

    const dynamic_lib_name = if (target.isWindows())
        "tinyvg.dll"
    else
        "tinyvg";

    const dynamic_native_lib = b.addSharedLibrary(dynamic_lib_name, "src/binding/binding.zig", .unversioned);
    initNativeLibrary(dynamic_native_lib, mode, target);
    if (install_lib) {
        dynamic_native_lib.install();
    }

    if (install_include) {
        const install_header = b.addInstallFileWithDir(.{ .path = "src/binding/include/tinyvg.h" }, .header, "tinyvg.h");
        b.getInstallStep().dependOn(&install_header.step);
    }

    const render = b.addExecutable("tvg-render", "src/tools/render.zig");
    render.setBuildMode(mode);
    render.setTarget(target);
    render.addPackage(pkgs.tvg);
    render.addPackage(pkgs.args);
    if (install_bin) {
        render.install();
    }

    const text = b.addExecutable("tvg-text", "src/tools/text.zig");
    text.setBuildMode(mode);
    text.setTarget(target);
    text.addPackage(pkgs.tvg);
    text.addPackage(pkgs.args);
    text.addPackage(pkgs.ptk);
    if (install_bin) {
        text.install();
    }

    const ground_truth_generator = b.addExecutable("ground-truth-generator", "src/data/ground-truth.zig");
    ground_truth_generator.setBuildMode(mode);
    ground_truth_generator.addPackage(pkgs.tvg);

    const generate_ground_truth = ground_truth_generator.run();
    generate_ground_truth.cwd = "zig-cache";

    const gen_gt_step = b.step("generate", "Regenerates the ground truth data.");

    const files = [_][]const u8{
        "shield-16.tvg",  "shield-8.tvg",      "shield-32.tvg",
        "everything.tvg", "everything-32.tvg",
    };
    inline for (files) |file| {
        const tvg_conversion = render.run();
        tvg_conversion.addArg(file);
        tvg_conversion.addArg("--super-sampling");
        tvg_conversion.addArg("2");
        tvg_conversion.addArg("--output");
        tvg_conversion.addArg(file[0 .. file.len - 3] ++ "tga");
        tvg_conversion.cwd = "zig-cache";
        tvg_conversion.step.dependOn(&generate_ground_truth.step);

        const tvgt_conversion = text.run();
        tvgt_conversion.addArg(file);
        tvgt_conversion.addArg("--output");
        tvgt_conversion.addArg(file[0 .. file.len - 3] ++ "tvgt");
        tvgt_conversion.cwd = "zig-cache";
        tvgt_conversion.step.dependOn(&generate_ground_truth.step);

        gen_gt_step.dependOn(&tvgt_conversion.step);
        gen_gt_step.dependOn(&tvg_conversion.step);
    }

    {
        const tvg_tests = b.addTestSource(pkgs.tvg.source);
        for (pkgs.tvg.dependencies.?) |dep| {
            tvg_tests.addPackage(dep);
        }

        tvg_tests.addPackage(std.build.Pkg{
            .name = "ground-truth",
            .source = .{ .path = "src/data/ground-truth.zig" },
            .dependencies = &[_]std.build.Pkg{
                pkgs.tvg,
            },
        });

        const static_binding_test = b.addExecutable("static-native-binding", null);
        static_binding_test.setBuildMode(mode);
        static_binding_test.linkLibC();
        static_binding_test.addIncludeDir("src/binding/include");
        static_binding_test.addCSourceFile("examples/usage.c", &[_][]const u8{ "-Wall", "-Wextra", "-pedantic", "-std=c99" });
        static_binding_test.linkLibrary(static_native_lib);

        const dynamic_binding_test = b.addExecutable("static-native-binding", null);
        dynamic_binding_test.setBuildMode(mode);
        dynamic_binding_test.linkLibC();
        dynamic_binding_test.addIncludeDir("src/binding/include");
        dynamic_binding_test.addCSourceFile("examples/usage.c", &[_][]const u8{ "-Wall", "-Wextra", "-pedantic", "-std=c99" });
        dynamic_binding_test.linkLibrary(dynamic_native_lib);

        const static_binding_test_run = static_binding_test.run();
        static_binding_test_run.cwd = "zig-cache";

        const dynamic_binding_test_run = dynamic_binding_test.run();
        dynamic_binding_test_run.cwd = "zig-cache";

        const test_step = b.step("test", "Runs all tests");
        test_step.dependOn(&tvg_tests.step);
        test_step.dependOn(&static_binding_test_run.step);
        test_step.dependOn(&dynamic_binding_test_run.step);
    }

    const polyfill = b.addSharedLibrary("tinyvg", "src/polyfill/tinyvg.zig", .unversioned);
    polyfill.strip = (mode != .Debug);
    polyfill.setBuildMode(mode);
    polyfill.setTarget(.{
        .cpu_arch = .wasm32,
        .cpu_model = .baseline,
        .os_tag = .freestanding,
    });
    polyfill.addPackage(pkgs.tvg);

    if (install_www) {
        polyfill.install();
        polyfill.install_step.?.dest_dir = www_folder;
    }

    const copy_stuff = b.addInstallFileWithDir(.{ .path = "src/polyfill/tinyvg.js" }, www_folder, "tinyvg.js");

    if (install_www) {
        b.getInstallStep().dependOn(&copy_stuff.step);
    }
}
