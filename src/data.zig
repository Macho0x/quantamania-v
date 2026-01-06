const std = @import("std");

/// Order side: Buy or Sell
pub const OrderSide = enum(u8) {
    buy = 0,
    sell = 1,

    pub fn opposite(self: OrderSide) OrderSide {
        return if (self == .buy) .sell else .buy;
    }
};

/// Order type
pub const OrderType = enum(u8) {
    market = 0,
    limit = 1,
    ioc = 2, // Immediate or Cancel
    fok = 3, // Fill or Kill
};

/// Order status
pub const OrderStatus = enum(u8) {
    pending = 0,
    filled = 1,
    rejected = 2,
    cancelled = 3,
    partially_filled = 4,
};

/// Packed order structure - exactly 8 bytes for cache efficiency
pub const Order = packed struct {
    order_id: u16,
    price: u16, // Price in cents (e.g., 10050 = $100.50)
    quantity: u16,
    side: OrderSide,
    order_type: OrderType,

    pub fn init(order_id: u16, price: u16, quantity: u16, side: OrderSide, order_type: OrderType) Order {
        return Order{
            .order_id = order_id,
            .price = price,
            .quantity = quantity,
            .side = side,
            .order_type = order_type,
        };
    }

    pub fn priceAsFloat(self: Order) f64 {
        return @as(f64, @floatFromInt(self.price)) / 100.0;
    }
};

// Compile-time assertion that Order is exactly 8 bytes
comptime {
    if (@sizeOf(Order) != 8) {
        @compileError("Order must be exactly 8 bytes");
    }
}

/// Market data message
pub const MarketDataMessage = struct {
    timestamp: i128, // Nanoseconds since epoch
    symbol: [8]u8, // Fixed-size symbol (e.g., "AAPL    ")
    price: u32, // Price in cents
    quantity: u32,
    side: OrderSide,

    pub fn init(timestamp: i128, symbol: [8]u8, price: u32, quantity: u32, side: OrderSide) MarketDataMessage {
        return MarketDataMessage{
            .timestamp = timestamp,
            .symbol = symbol,
            .price = price,
            .quantity = quantity,
            .side = side,
        };
    }

    pub fn priceAsFloat(self: MarketDataMessage) f64 {
        return @as(f64, @floatFromInt(self.price)) / 100.0;
    }

    pub fn symbolAsString(self: MarketDataMessage) []const u8 {
        var end: usize = 0;
        while (end < 8 and self.symbol[end] != ' ' and self.symbol[end] != 0) : (end += 1) {}
        return self.symbol[0..end];
    }
};

/// Position tracking
pub const Position = struct {
    symbol: [8]u8,
    quantity: i64, // Positive = long, negative = short
    avg_price: f64,
    realized_pnl: f64,
    unrealized_pnl: f64,
    max_position: i64,

    pub fn init(symbol: [8]u8, max_position: i64) Position {
        return Position{
            .symbol = symbol,
            .quantity = 0,
            .avg_price = 0.0,
            .realized_pnl = 0.0,
            .unrealized_pnl = 0.0,
            .max_position = max_position,
        };
    }

    pub fn updatePosition(self: *Position, side: OrderSide, quantity: i64, price: f64) void {
        const signed_qty: i64 = if (side == .buy) quantity else -quantity;

        if (self.quantity == 0) {
            // Opening new position
            self.quantity = signed_qty;
            self.avg_price = price;
        } else if ((self.quantity > 0 and signed_qty > 0) or (self.quantity < 0 and signed_qty < 0)) {
            // Adding to position
            const total_cost = self.avg_price * @as(f64, @floatFromInt(@abs(self.quantity))) +
                price * @as(f64, @floatFromInt(@abs(signed_qty)));
            self.quantity += signed_qty;
            if (self.quantity != 0) {
                self.avg_price = total_cost / @as(f64, @floatFromInt(@abs(self.quantity)));
            }
        } else {
            // Reducing or reversing position
            const closing_qty = @min(@abs(self.quantity), @abs(signed_qty));
            const pnl = if (self.quantity > 0)
                (price - self.avg_price) * @as(f64, @floatFromInt(closing_qty))
            else
                (self.avg_price - price) * @as(f64, @floatFromInt(closing_qty));

            self.realized_pnl += pnl;
            self.quantity += signed_qty;

            if ((self.quantity > 0 and signed_qty > 0) or (self.quantity < 0 and signed_qty < 0)) {
                // Position reversed
                self.avg_price = price;
            }
        }
    }

    pub fn calculateUnrealizedPnL(self: *Position, current_price: f64) void {
        if (self.quantity == 0) {
            self.unrealized_pnl = 0.0;
        } else if (self.quantity > 0) {
            self.unrealized_pnl = (current_price - self.avg_price) * @as(f64, @floatFromInt(self.quantity));
        } else {
            self.unrealized_pnl = (self.avg_price - current_price) * @as(f64, @floatFromInt(-self.quantity));
        }
    }

    pub fn totalPnL(self: Position) f64 {
        return self.realized_pnl + self.unrealized_pnl;
    }

    pub fn isWithinLimits(self: Position) bool {
        return @abs(self.quantity) <= self.max_position;
    }
};

/// Price level for order book
pub const PriceLevel = struct {
    price: u32,
    quantity: u64,

    pub fn init(price: u32, quantity: u64) PriceLevel {
        return PriceLevel{
            .price = price,
            .quantity = quantity,
        };
    }
};

test "Order size is 8 bytes" {
    try std.testing.expectEqual(8, @sizeOf(Order));
}

test "Order initialization" {
    const order = Order.init(1, 10050, 100, .buy, .limit);
    try std.testing.expectEqual(@as(u16, 1), order.order_id);
    try std.testing.expectEqual(@as(u16, 10050), order.price);
    try std.testing.expectEqual(@as(u16, 100), order.quantity);
    try std.testing.expectEqual(OrderSide.buy, order.side);
    try std.testing.expectEqual(OrderType.limit, order.order_type);
}

test "Position tracking" {
    var pos = Position.init([_]u8{ 'A', 'A', 'P', 'L', ' ', ' ', ' ', ' ' }, 1000);

    // Buy 100 @ 150
    pos.updatePosition(.buy, 100, 150.0);
    try std.testing.expectEqual(@as(i64, 100), pos.quantity);
    try std.testing.expectEqual(@as(f64, 150.0), pos.avg_price);

    // Buy 100 @ 160
    pos.updatePosition(.buy, 100, 160.0);
    try std.testing.expectEqual(@as(i64, 200), pos.quantity);
    try std.testing.expectEqual(@as(f64, 155.0), pos.avg_price);

    // Sell 100 @ 170
    pos.updatePosition(.sell, 100, 170.0);
    try std.testing.expectEqual(@as(i64, 100), pos.quantity);
    try std.testing.expect(pos.realized_pnl > 1400.0 and pos.realized_pnl < 1600.0);
}
