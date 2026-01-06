const std = @import("std");
const types = @import("../base/types.zig");

// Market limits
pub const MarketLimits = struct {
    amount: struct { min: ?f64, max: ?f64 } = .{ .min = null, .max = null },
    price: struct { min: ?f64, max: ?f64 } = .{ .min = null, .max = null },
    cost: struct { min: ?f64, max: ?f64 } = .{ .min = null, .max = null },
    leverage: struct { min: ?u32, max: ?u32 } = .{ .min = null, .max = null },
    
    pub fn format(
        self: MarketLimits,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "Limits{{amount: {{min: {?d:.2}, max: {?d:.2}}}, " ++
            "price: {{min: {?d:.2}, max: {?d:.2}}}, " ++
            "cost: {{min: {?d:.2}, max: {?d:.2}}}, " ++
            "leverage: {{min: {?d}, max: {?d}}}}}",
            .{
                self.amount.min, self.amount.max,
                self.price.min, self.price.max,
                self.cost.min, self.cost.max,
                self.leverage.min, self.leverage.max,
            },
        );
    }
};

// Market fees
pub const MarketFees = struct {
    trading: f64 = 0.001, // Default 0.1%
    maker: ?f64 = null,
    taker: ?f64 = null,
    withdrawal: ?f64 = null,
    deposit: ?f64 = null,
    
    pub fn format(
        self: MarketFees,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Fees{{trading: {d:.4}, maker: {?d:.4}, taker: {?d:.4}, withdraw: {?d:.4}, deposit: {?d:.4}}}", .{
            self.trading, self.maker, self.taker, self.withdrawal, self.deposit,
        });
    }
};

// Market precision
pub const MarketPrecision = struct {
    amount: ?u8 = null,
    price: ?u8 = null,
    base: ?u8 = null,
    quote: ?u8 = null,
    
    pub fn format(
        self: MarketPrecision,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Precision{{amount: {?d}, price: {?d}, base: {?d}, quote: {?d}}}", .{
            self.amount, self.price, self.base, self.quote,
        });
    }
};

// Main Market structure
pub const Market = struct {
    // Basic identifiers
    id: []const u8,
    symbol: []const u8,
    base: []const u8,
    quote: []const u8,
    baseId: ?[]const u8,
    quoteId: ?[]const u8,
    
    // Market characteristics
    active: bool = true,
    taker: ?f64 = null,
    maker: ?f64 = null,
    percentage: ?bool = true,
    tierBased: ?bool = false,
    
    // Trading mode and type
    type: ?types.OrderType = null,
    spot: bool = false,
    margin: bool = false,
    future: bool = false,
    swap: bool = false,
    option: bool = false,
    contract: bool = false,
    settle: ?[]const u8 = null,
    settleId: ?[]const u8 = null,
    
    // Structured data
    limits: MarketLimits = .{},
    precision: MarketPrecision = .{},
    info: ?std.json.Value = null,
    
    // Margin/future specific
    leverage: ?f64 = null,
    expiry: ?i64 = null,
    expiryDatetime: ?[]const u8 = null,
    strike: ?f64 = null,
    optionType: ?[]const u8 = null,
    
    pub fn deinit(self: *Market, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.symbol);
        allocator.free(self.base);
        allocator.free(self.quote);
        if (self.baseId) |b| allocator.free(b);
        if (self.quoteId) |q| allocator.free(q);
        if (self.settle) |s| allocator.free(s);
        if (self.settleId) |s| allocator.free(s);
        if (self.expiryDatetime) |e| allocator.free(e);
        if (self.optionType) |o| allocator.free(o);
        if (self.info) |info| switch (info) {
            .object => |obj| obj.deinit(),
            else => {},
        };
    }
    
    pub fn format(
        self: Market,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Market{{{ s}/{ s}, active: {}, type: {?s}, limits: {}, precision: {}}}", .{
            self.base,
            self.quote,
            self.active,
            self.type,
            self.limits,
            self.precision,
        });
    }
};