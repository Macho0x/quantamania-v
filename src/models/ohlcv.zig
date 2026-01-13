const std = @import("std");
const types = @import("../base/types.zig");

// OHLCV structure representing candlestick data
pub const OHLCV = struct {
    timestamp: types.Timestamp,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
    
    // Additional fields for some exchanges
    quoteVolume: ?f64 = null,
    count: ?u32 = null,
    takerBuyBaseVolume: ?f64 = null,
    takerBuyQuoteVolume: ?f64 = null,
    
    pub fn toArray(self: OHLCV) [6]f64 {
        return .{
            @floatFromInt(self.timestamp),
            self.open,
            self.high,
            self.low,
            self.close,
            self.volume,
        };
    }
    
    pub fn fromArray(arr: [6]f64) OHLCV {
        return .{
            .timestamp = @intFromFloat(arr[0]),
            .open = arr[1],
            .high = arr[2],
            .low = arr[3],
            .close = arr[4],
            .volume = arr[5],
        };
    }
};