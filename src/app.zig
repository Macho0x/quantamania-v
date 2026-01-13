const std = @import("std");
const ccxt = @import("ccxt_zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("ccxt-zig {s}\n", .{ccxt.VERSION});
    try stdout.print("Commands:\n", .{});
    try stdout.print("  zig build examples   # run examples\n", .{});
    try stdout.print("  zig build benchmark  # run benchmarks\n", .{});
    try stdout.print("  zig build test       # run unit tests\n", .{});
}
