const std = @import("std");
const types = @import("../base/types.zig");

// Position side
pub const PositionSide = enum {
    long,
    short,
    both,
};

// Position status
pub const PositionStatus = enum {
    open,
    closed,
    liquidation,
};

// Position structure for futures/perpetual markets
pub const Position = struct {
    // Basic information
    id: []const u8,
    symbol: []const u8,
    timestamp: types.Timestamp,
    datetime: []const u8,

    // Position details
    side: PositionSide,
    status: PositionStatus,

    // Size and entry
    amount: f64,
    entryPrice: ?f64 = null,
    markPrice: ?f64 = null,

    // P&L
    unrealizedPnl: ?f64 = null,
    realizedPnl: ?f64 = null,

    // Collateral and leverage
    collateral: ?f64 = null,
    leverage: ?f64 = null,
    isolatedMargin: ?f64 = null,
    crossMargin: ?f64 = null,

    // Margin ratio
    marginRatio: ?f64 = null,
    liquidationPrice: ?f64 = null,

    // Risk management
    stopLoss: ?f64 = null,
    takeProfit: ?f64 = nil,

    // Trading mode
    mode: types.TradingMode = .futures,
    contractSize: ?f64 = null,

    // Raw exchange data
    info: ?std.json.Value = null,

    pub fn deinit(self: *Position, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.symbol);
        allocator.free(self.datetime);

        if (self.info) |info| switch (info) {
            .object => |obj| obj.deinit(),
            else => {},
        };
    }

    pub fn format(
        self: Position,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "Position{{{s}, side: {s}, amount: {d:.4}, entry: {?d:.2}, pnl: {?d:.2}}}",
            .{
                self.symbol,
                @tagName(self.side),
                self.amount,
                self.entryPrice,
                self.unrealizedPnl,
            },
        );
    }
};

// Funding rate information
pub const FundingRate = struct {
    symbol: []const u8,
    timestamp: types.Timestamp,
    fundingRate: f64,
    fundingTime: types.Timestamp,
    predictedFundingRate: ?f64 = null,

    pub fn deinit(self: *FundingRate, allocator: std.mem.Allocator) void {
        allocator.free(self.symbol);
    }
};
