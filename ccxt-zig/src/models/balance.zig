const std = @import("std");
const types = @import("../base/types.zig");

pub const Balance = struct {
    // Balance amounts
    free: types.Decimal,
    used: types.Decimal,
    total: types.Decimal,
    
    // Additional information
    currency: []const u8,
    percentage: ?f64 = null,
    usdValue: ?f64 = null,
    
    // Timestamps
    timestamp: types.Timestamp,
    
    // Raw exchange data
    info: ?std.json.Value = null,
    
    pub fn init(currency: []const u8, free: types.Decimal, used: types.Decimal, total: types.Decimal, timestamp: types.Timestamp) Balance {
        return .{
            .free = free,
            .used = used,
            .total = total,
            .currency = currency,
            .timestamp = timestamp,
            .info = null,
        };
    }
    
    pub fn deinit(self: *Balance, allocator: std.mem.Allocator) void {
        allocator.free(self.currency);
        if (self.info) |info| switch (info) {
            .object => |obj| obj.deinit(),
            else => {},
        };
    }
    
    pub fn format(
        self: Balance,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "Balance{{currency: {s}, free: {}, used: {}, total: {}, timestamp: {d}}}",
            .{ self.currency, self.free, self.used, self.total, self.timestamp },
        );
    }
};