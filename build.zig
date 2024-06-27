//Stolen from https://github.com/hexops/glfw/blob/master/build.zig
//
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shared = b.option(
        bool,
        "shared",
        "Build as shared library",
    ) orelse false;

    const use_metal = b.option(
        bool,
        "metal",
        "Build with metal support; MacOS only",
    ) orelse true;

    const use_opengl = b.option(
        bool,
        "opengl",
        "Use OpenGL. Deprecated on MacOS",
    ) orelse true;

    const use_gles = b.option(
        bool,
        "gles",
        "Use GLES. Not supported in MacOS",
    ) orelse false;

    _ = use_gles;

    const lib = std.Build.Step.Compile.create(b, .{
        .name = "glfw",
        .kind = .lib,
        .linkage = if (shared) .dynamic else .static,
        .root_module = .{
            .target = target,
            .optimize = optimize,
        },
    });

    lib.addIncludePath(b.path("include"));
    lib.linkLibC();

    if (shared) lib.defineCMacro("_GLFW_BUILD_DLL", "1");

    lib.installHeadersDirectory(b.path("include/GLFW/"), "GLFW", .{});

    if (target.result.isDarwin()) {
        lib.defineCMacro("__kernel_ptr_semantics", "");
    }

    const include_src_flag = "-Isrc";

    switch (target.result.os.tag) {
        .macos => {
            // Transitive dependencies, explicit linkage of these works around
            // ziglang/zig#17130
            lib.linkFramework("CFNetwork");
            lib.linkFramework("ApplicationServices");
            lib.linkFramework("ColorSync");
            lib.linkFramework("CoreText");
            lib.linkFramework("ImageIO");

            //Direct dependencies
            lib.linkSystemLibrary("objc");
            lib.linkFramework("IOKit");
            lib.linkFramework("CoreFoundation");
            lib.linkFramework("AppKit");
            lib.linkFramework("CoreServices");
            lib.linkFramework("CoreGraphics");
            lib.linkFramework("Foundation");
            lib.linkFramework("QuartzCore"); //CAMetalLayer giving undefined

            if (use_metal) {
                lib.linkFramework("Metal");
            }

            if (use_opengl) {
                lib.linkFramework("OpenGL");
            }

            const flags = [_][]const u8{ "-D_GLFW_COCOA", include_src_flag };
            lib.addCSourceFiles(.{
                .files = &base_source_files,
                .flags = &flags,
            });

            lib.addCSourceFiles(.{ .files = &macos_source_files, .flags = &flags });
        },
        else => {
            std.debug.print("only building for MacOS right now\n", .{});
            unreachable;
        },
    }

    b.installArtifact(lib);

    const examples = [_][]const u8{
        "boing",
        "gears",
        "triangle-opengl",
        "sharing",
        "splitview",
        "heightmap",
        "offscreen",
        "windows",
        "wave",
        // "particles", // Requires C11
    };

    inline for (examples) |example| {
        build_example(example, .{
            .builder = b,
            .target = target,
            .optimize = optimize,
            .lib = lib,
        });
    }
}

fn build_example(
    comptime name: []const u8,
    opts: struct {
        builder: *std.Build,
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
        lib: *std.Build.Step.Compile,
    },
) void {
    const exe = opts.builder.addExecutable(.{
        .name = name,
        .target = opts.target,
        .optimize = opts.optimize,
    });

    exe.linkLibrary(opts.lib);

    exe.addIncludePath(opts.builder.path("deps"));

    const path = "examples/" ++ name ++ ".c";

    exe.addCSourceFiles(.{ .files = &.{path} });

    opts.builder.installArtifact(exe);
}

const base_source_files = [_][]const u8{
    "src/context.c",
    "src/egl_context.c",
    "src/init.c",
    "src/input.c",
    "src/monitor.c",
    "src/null_init.c",
    "src/null_joystick.c",
    "src/null_monitor.c",
    "src/null_window.c",
    "src/osmesa_context.c",
    "src/platform.c",
    "src/vulkan.c",
    "src/window.c",
};

const macos_source_files = [_][]const u8{
    //C Sources
    "src/cocoa_time.c",
    "src/posix_module.c",
    "src/posix_thread.c",

    //ObjC Sources
    "src/cocoa_init.m",
    "src/cocoa_joystick.m",
    "src/cocoa_monitor.m",
    "src/cocoa_window.m",
    "src/nsgl_context.m",
};
