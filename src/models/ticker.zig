const std = @import("std");
const types = @import("../base/types.zig");

pub const Ticker = struct {
    symbol: []const u8,
    timestamp: types.Timestamp,
    
    // Price information
    high: ?f64 = null,
    low: ?f64 = null,
    bid: ?f64 = null,
    bidVolume: ?f64 = null,
    ask: ?f64 = null,
    askVolume: ?f64 = null,
    
    // Recent trade information
    last: ?f64 = null,
    open: ?f64 = null,
    close: ?f64 = null,
    previousClose: ?f64 = null,
    
    // Volume information
    baseVolume: ?f64 = null,
    quoteVolume: ?f64 = null,
    
    // Statistics
    percentage: ?f64 = null,
    average: ?f64 = null,
    vwap: ?f64 = null,
    
    // Order book depth
    change: ?f64 = null,
    
    // Raw exchange data
    info: ?std.json.Value = null,
    
    pub fn deinit(self: *Ticker, allocator: std.mem.Allocator) void {
        allocator.free(self.symbol);
        if (self.info) |info| switch (info) {
            .object => |obj| obj.deinit(),
            else => {},
        };
    }
    
    pub fn format(
        self: Ticker,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "Ticker{{{s}, last: {?d:.2}, high: {?d:.2}, low: {?d:.2}, bid: {?d:.2}, ask: {?d:.2}, volume: {?d:.2}}}",
            .{ self.symbol, self.last, self.high, self.low, self.bid, self.ask, self.baseVolume },
        );
    }
};