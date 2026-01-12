const std = @import("std");

// Decimal type for precise price/amount handling
pub const Decimal = struct {
    value: i128,
    scale: u8,
    
    pub fn fromString(allocator: std.mem.Allocator, str: []const u8) !Decimal {
        // Simple implementation - in production, use a proper decimal library
        const parsed = try std.fmt.parseFloat(f64, str);
        return Decimal{
            .value = @as(i128, @intFromFloat(@round(parsed * 100_000_000))),
            .scale = 8,
        };
    }
    
    pub fn format(
        self: Decimal,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const integer_part = self.value / std.math.pow(i64, 10, self.scale);
        const fractional_part = @abs(self.value % std.math.pow(i64, 10, self.scale));
        
        try writer.print("{d}.{d:0>{}}", .{ integer_part, fractional_part, self.scale });
    }
};

// Timestamp type in milliseconds
pub const Timestamp = i64;

// Order type enum
pub const OrderType = enum {
    spot,
    margin,
    futures,
    swap,
    option,
    
    pub fn asString(self: OrderType) []const u8 {
        return switch (self) {
            .spot => "spot",
            .margin => "margin",
            .futures => "futures",
            .swap => "swap",
            .option => "option",
        };
    }
};

// Timeframe enum
pub const TimeFrame = enum {
    _1m, _5m, _15m, _30m, 
    _1h, _2h, _4h, _6h, _8h, _12h, 
    _1d, _3d, 
    _1w, _2w, 
    _1M,
    
    pub fn toMinutes(self: TimeFrame) i64 {
        return switch (self) {
            ._1m => 1,
            ._5m => 5,
            ._15m => 15,
            ._30m => 30,
            ._1h => 60,
            ._2h => 120,
            ._4h => 240,
            ._6h => 360,
            ._8h => 480,
            ._12h => 720,
            ._1d => 1440,
            ._3d => 4320,
            ._1w => 10080,
            ._2w => 20160,
            ._1M => 43200,
        };
    }
    
    pub fn toString(self: TimeFrame) []const u8 {
        return switch (self) {
            ._1m => "1m",
            ._5m => "5m",
            ._15m => "15m",
            ._30m => "30m",
            ._1h => "1h",
            ._2h => "2h",
            ._4h => "4h",
            ._6h => "6h",
            ._8h => "8h",
            ._12h => "12h",
            ._1d => "1d",
            ._3d => "3d",
            ._1w => "1w",
            ._2w => "2w",
            ._1M => "1M",
        };
    }
};

// Rate limit types
pub const RateLimitType = enum {
    requests_per_second,
    requests_per_minute,
    requests_per_hour,
    requests_per_day,
    orders_per_second,
    orders_per_minute,
};

// Trading mode enum
pub const TradingMode = enum {
    spot,
    margin,
    leverage,
    futures,
    option,
    
    pub fn asString(self: TradingMode) []const u8 {
        return switch (self) {
            .spot => "spot",
            .margin => "margin",
            .leverage => "leverage",
            .futures => "futures",
            .option => "option",
        };
    }
};

// Parse price from string
pub fn parsePrice(allocator: std.mem.Allocator, str: []const u8) !Decimal {
    return Decimal.fromString(allocator, str);
}

// Format price for display
pub fn formatPrice(price: Decimal, precision: u8) []const u8 {
    // Format decimal with given precision
    var buffer: [100]u8 = undefined;
    const scaled = @as(f64, @floatFromInt(price.value)) / std.math.pow(f64, 10.0, @as(f32, @floatFromInt(price.scale)));
    const formatted = std.fmt.bufPrint(&buffer, "{d:.1$}", .{ scaled, @intCast(precision) }) catch return "0.0";
    return formatted;
}

// Exchange field mapping for exchange-specific API formats
// Allows exchanges to map their field names (like px, sz) to standard names (price, amount)
pub const ExchangeFieldMapping = struct {
    // Core order/trade fields
    price: []const u8 = "price",
    amount: []const u8 = "amount",
    cost: []const u8 = "cost",
    order_id: []const u8 = "id",
    client_order_id: []const u8 = "clientOrderId",
    symbol: []const u8 = "symbol",
    side: []const u8 = "side",
    type: []const u8 = "type",
    timestamp: []const u8 = "timestamp",
    datetime: []const u8 = "datetime",

    // Order book specific
    bid_price: []const u8 = "bid",
    bid_amount: []const u8 = "bidAmount",
    ask_price: []const u8 = "ask",
    ask_amount: []const u8 = "askAmount",

    // Ticker specific
    high: []const u8 = "high24h",
    low: []const u8 = "low24h",
    open: []const u8 = "open24h",
    close: []const u8 = "close",
    last: []const u8 = "lastPrice",
    previous_close: []const u8 = "prevClosePrice",
    change: []const u8 = "changePrice",
    change_percent: []const u8 = "changePercent",
    average: []const u8 = "avgPrice",
    base_volume: []const u8 = "volume24h",
    quote_volume: []const u8 = "quoteVolume",

    // Balance specific
    free: []const u8 = "free",
    used: []const u8 = "used",
    total: []const u8 = "total",

    // Market info specific
    tick_size: []const u8 = "tickSize",
    lot_size: []const u8 = "lotSize",
    min_size: []const u8 = "minSize",
    max_size: []const u8 = "maxSize",
    max_price: []const u8 = "maxPrice",
    min_price: []const u8 = "minPrice",

    // Order status
    status: []const u8 = "status",
    filled: []const u8 = "filled",
    remaining: []const u8 = "remaining",
    average_price: []const u8 = "avgPrice",

    // Fee
    fee: []const u8 = "fee",
    fee_currency: []const u8 = "feeCurrency",

    // Identifier fields
    trade_id: []const u8 = "tradeId",
    order_type: []const u8 = "orderType",

    // Helper function to get field name
    pub fn getPrice(self: *const ExchangeFieldMapping) []const u8 {
        return self.price;
    }

    pub fn getAmount(self: *const ExchangeFieldMapping) []const u8 {
        return self.amount;
    }

    pub fn getOrderId(self: *const ExchangeFieldMapping) []const u8 {
        return self.order_id;
    }

    pub fn getClientOrderId(self: *const ExchangeFieldMapping) []const u8 {
        return self.client_order_id;
    }

    pub fn getSymbol(self: *const ExchangeFieldMapping) []const u8 {
        return self.symbol;
    }

    pub fn getSide(self: *const ExchangeFieldMapping) []const u8 {
        return self.side;
    }

    pub fn getTimestamp(self: *const ExchangeFieldMapping) []const u8 {
        return self.timestamp;
    }
};

// Standard field mappings for common exchanges
pub const StandardFieldMapping = ExchangeFieldMapping{};

// OKX uses abbreviated field names (px=price, sz=size)
pub const OKXFieldMapping = ExchangeFieldMapping{
    .price = "px",
    .amount = "sz",
    .order_id = "ordId",
    .client_order_id = "clOrdId",
    .bid_price = "bidPx",
    .bid_amount = "bidSz",
    .ask_price = "askPx",
    .ask_amount = "askSz",
    .tick_size = "tickSz",
    .lot_size = "lotSz",
    .min_size = "minSz",
    .last = "lastPx",
    .base_volume = "vol24h",
    .quote_volume = "volCcy24h",
    .high = "high24h",
    .low = "low24h",
};

// Hyperliquid uses very abbreviated field names
pub const HyperliquidFieldMapping = ExchangeFieldMapping{
    .price = "px",
    .amount = "sz",
    .order_id = "oid",
    .client_order_id = "cloid",
    .symbol = "s",
    .side = "side",
    .type = "orderType",
    .timestamp = "time",
    .filled = "filledSz",
    .remaining = "remainingSz",
    .average_price = "avgPx",
};

// Bybit uses mixed naming conventions
pub const BybitFieldMapping = ExchangeFieldMapping{
    .price = "price",
    .amount = "qty",
    .order_id = "orderId",
    .client_order_id = "orderLinkId",
    .symbol = "symbol",
    .side = "side",
    .type = "orderType",
    .timestamp = "createdTime",
    .status = "orderStatus",
    .filled = "cumExecQty",
    .remaining = "leavesQty",
    .average_price = "avgPrice",
    .base_volume = "volume24h",
    .tick_size = "priceScale",
    .lot_size = "baseScale",
};

// Parse trading pair symbol
pub fn parsePair(allocator: std.mem.Allocator, symbol: []const u8) !struct { base: []const u8, quote: []const u8 } {
    const delimiter = "/";
    var it = std.mem.split(u8, symbol, delimiter);
    
    const base = it.next() orelse return error.InvalidSymbol;
    const quote = it.next() orelse return error.InvalidSymbol;
    
    return .{
        .base = base,
        .quote = quote,
    };
}