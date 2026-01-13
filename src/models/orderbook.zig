const std = @import("std");

// Order book side (bid/ask)
pub const OrderBookSide = enum {
    bid,
    ask,
};

// Order book entry
pub const OrderBookEntry = struct {
    price: f64,
    amount: f64,
    timestamp: i64,
    orderCount: ?u32 = null,
};

// Main OrderBook structure
pub const OrderBook = struct {
    // Basic information
    symbol: []const u8,
    timestamp: i64,
    datetime: []const u8,

    // Order book sides
    bids: []OrderBookEntry,
    asks: []OrderBookEntry,

    // Sequence information
    sequence: ?i64 = null,
    nonce: ?i64 = null,

    // Snapshot vs streaming
    is_snapshot: bool = true,

    // Raw exchange data
    info: ?std.json.Value = null,

    pub fn deinit(self: *OrderBook, allocator: std.mem.Allocator) void {
        allocator.free(self.symbol);
        allocator.free(self.datetime);

        for (self.bids) |entry| {
            allocator.free(entry);
        }
        allocator.free(self.bids);

        for (self.asks) |entry| {
            allocator.free(entry);
        }
        allocator.free(self.asks);

        if (self.info) |info| switch (info) {
            .object => |obj| obj.deinit(),
            else => {},
        };
    }

    pub fn format(
        self: OrderBook,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "OrderBook{{{s}, bids: {d}, asks: {d}, timestamp: {d}}}",
            .{ self.symbol, self.bids.len, self.asks.len, self.timestamp },
        );
    }
};

// Best bid/ask snapshot
pub const BestBidAsk = struct {
    symbol: []const u8,
    timestamp: i64,
    bidPrice: ?f64 = null,
    bidAmount: ?f64 = null,
    askPrice: ?f64 = null,
    askAmount: ?f64 = null,

    pub fn deinit(self: *BestBidAsk, allocator: std.mem.Allocator) void {
        allocator.free(self.symbol);
    }
};
