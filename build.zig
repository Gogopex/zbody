const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
const sokol = @import("sokol");
const zlm: type = @import("zlm");

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    // const dep_zlm = b.dependency("zlm", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    // special case handling for native vs web build
    if (target.result.isWasm()) {
        try buildWeb(b, target, optimize, dep_sokol);
    } else {
        try buildNative(b, target, optimize, dep_sokol);
    }
}

fn buildNative(b: *Build, target: Build.ResolvedTarget, optimize: OptimizeMode, dep_sokol: *Build.Dependency) !void {
    const zbody = b.addExecutable(.{
        .name = "zbody",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/main.zig" },
    });
    zbody.root_module.addImport("sokol", dep_sokol.module("sokol"));
    // zbody.root_module.addImport("zlm", dep_zlm.module("zlm"));

    b.installArtifact(zbody);
    const run = b.addRunArtifact(zbody);
    b.step("run", "Run zbody").dependOn(&run.step);
}

fn buildWeb(b: *Build, target: Build.ResolvedTarget, optimize: OptimizeMode, dep_sokol: *Build.Dependency) !void {
    const zbody = b.addStaticLibrary(.{
        .name = "zbody",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/main.zig" },
    });
    zbody.root_module.addImport("sokol", dep_sokol.module("sokol"));
    // zbody.root_module.addImport("zlm", dep_zlm.module("zlm"));

    // create a build step which invokes the Emscripten linker
    const emsdk = dep_sokol.builder.dependency("emsdk", .{});
    const link_step = try sokol.emLinkStep(b, .{
        .lib_main = zbody,
        .target = target,
        .optimize = optimize,
        .emsdk = emsdk,
        .use_webgl2 = true,
        .use_emmalloc = true,
        .use_filesystem = false,
        .shell_file_path = dep_sokol.path("src/sokol/web/shell.html").getPath(b),
    });
    // ...and a special run step to start the web build output via 'emrun'
    const run = sokol.emRunStep(b, .{ .name = "zbody-wasm", .emsdk = emsdk });
    run.step.dependOn(&link_step.step);
    b.step("run", "Run zbody-wasm").dependOn(&run.step);
}
