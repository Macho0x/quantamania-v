const std = @import("std");

pub const OrderType = enum {
    market,
    limit,
    stop,
    stop_limit,
    take_profit,
    take_profit_limit,
    trailing_stop,
    trailing_stop_limit,
    
    pub fn asString(self: OrderType) []const u8 {
        return switch (self) {
            .market => "market",
            .limit => "limit",
            .stop => "stop",
            .stop_limit => "stop_limit",
            .take_profit => "take_profit",
            .take_profit_limit => "take_profit_limit",
            .trailing_stop => "trailing_stop",
            .trailing_stop_limit => "trailing_stop_limit",
        };
    }
};

pub const OrderSide = enum {
    buy,
    sell,
    
    pub fn asString(self: OrderSide) []const u8 {
        return switch (self) {
            .buy => "buy",
            .sell => "sell",
        };
    }
};

pub const OrderStatus = enum {
    open,
    closed,
    canceled,
    pending,
    rejected,
    expired,
    
    pub fn asString(self: OrderStatus) []const u8 {
        return switch (self) {
            .open => "open",
            .closed => "closed",
            .canceled => "canceled",
            .pending => "pending",
            .rejected => "rejected",
            .expired => "expired",
        };
    }
};

pub const Order = struct {
    // Basic order information
    id: []const u8,
    clientOrderId: ?[]const u8 = null,
    timestamp: i64,
    datetime: []const u8,
    lastTradeTimestamp: ?i64 = null,
    lastUpdateTimestamp: ?i64 = null,
    
    // Market and trade details
    symbol: []const u8,
    type: OrderType,
    side: OrderSide,
    
    // Order parameters
    price: f64 = 0,
    amount: f64 = 0,
    cost: f64 = 0,
    average: ?f64 = null,
    filled: f64 = 0,
    remaining: f64 = 0,
    
    // Status
    status: OrderStatus,
    
    // Fee information
    fee: ?struct {
        currency: []const u8 = "",
        cost: f64 = 0,
        rate: ?f64 = null,
    } = null,
    
    // Related trades
    trades: ?std.ArrayList([]const u8) = null,
    fees: ?std.ArrayList([]const u8) = null,
    
    // Raw exchange data
    info: ?std.json.Value = null,
    
    pub fn deinit(self: *Order, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        if (self.clientOrderId) |c| allocator.free(c);
        allocator.free(self.datetime);
        allocator.free(self.symbol);
        if (self.fee) |f| allocator.free(f.currency);
        if (self.trades) |trades| {
            for (trades.items) |trade| allocator.free(trade);
            trades.deinit();
        }
        if (self.fees) |fees| {
            for (fees.items) |fee| allocator.free(fee);
            fees.deinit();
        }
        if (self.info) |info| switch (info) {
            .object => |obj| obj.deinit(),
            else => {},
        };
    }
};