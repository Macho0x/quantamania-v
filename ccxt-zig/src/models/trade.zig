const std = @import("std");
const types = @import("../base/types.zig");

pub const TradeType = enum {
    spot,
    margin,
    futures,
    swap,
    option,
    
    pub fn asString(self: TradeType) []const u8 {
        return switch (self) {
            .spot => "spot",
            .margin => "margin",
            .futures => "futures",
            .swap => "swap",
            .option => "option",
        };
    }
};

pub const Trade = struct {
    // Trade identifiers
    id: []const u8,
    order: ?[]const u8 = null,
    clientOrderId: ?[]const u8 = null,
    
    // Trade details
    timestamp: types.Timestamp,
    datetime: []const u8,
    symbol: []const u8,
    type: TradeType,
    side: []const u8, // "buy" or "sell"
    
    // Trade amounts
    price: f64,
    amount: f64,
    cost: f64,
    
    // Fee information
    fee: ?struct {
        currency: []const u8 = "",
        cost: f64 = 0,
        rate: ?f64 = null,
    } = null,
    
    // Additional info
    takerOrMaker: ?[]const u8 = null,
    
    // Raw exchange data
    info: ?std.json.Value = null,
    
    pub fn deinit(self: *Trade, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        if (self.order) |o| allocator.free(o);
        if (self.clientOrderId) |c| allocator.free(c);
        allocator.free(self.datetime);
        allocator.free(self.symbol);
        allocator.free(self.side);
        if (self.fee) |f| allocator.free(f.currency);
        if (self.takerOrMaker) |t| allocator.free(t);
        if (self.info) |info| switch (info) {
            .object => |obj| obj.deinit(),
            else => {},
        };
    }
};