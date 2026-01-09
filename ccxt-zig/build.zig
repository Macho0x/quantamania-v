const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const use_websocket = b.option(bool, "websocket", "Enable WebSocket support") orelse false;

    // Main library/executable
    const exe = b.addExecutable(.{
        .name = "ccxt",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (use_websocket) {
        exe.root_module.addImport("websocket", b.path("src/websocket/ws.zig"));
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Examples
    const examples = b.addExecutable(.{
        .name = "examples",
        .root_source_file = b.path("examples.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(examples);

    const run_examples = b.addRunArtifact(examples);
    const examples_step = b.step("examples", "Run examples");
    examples_step.dependOn(&run_examples.step);

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .name = "lib-tests",
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Benchmark
    const benchmark = b.addExecutable(.{
        .name = "benchmark",
        .root_source_file = b.path("benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(benchmark);

    const run_benchmark = b.addRunArtifact(benchmark);
    const benchmark_step = b.step("benchmark", "Run performance benchmarks");
    benchmark_step.dependOn(&run_benchmark.step);
}
