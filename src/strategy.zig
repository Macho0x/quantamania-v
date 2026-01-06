const std = @import("std");
const data = @import("data.zig");
const structures = @import("structures.zig");
const Order = data.Order;
const OrderSide = data.OrderSide;
const OrderType = data.OrderType;
const MarketDataMessage = data.MarketDataMessage;
const OrderBook = structures.OrderBook;

/// Strategy interface with callbacks
pub const Strategy = struct {
    const Self = @This();

    vtable: *const VTable,
    ptr: *anyopaque,

    pub const VTable = struct {
        onMarketData: *const fn (ptr: *anyopaque, msg: MarketDataMessage, book: *OrderBook, order_id_counter: *u16) ?Order,
        onOrderFill: *const fn (ptr: *anyopaque, order_id: u16, quantity: u16, price: u16) void,
        onOrderRejection: *const fn (ptr: *anyopaque, order_id: u16, reason: []const u8) void,
        getName: *const fn (ptr: *anyopaque) []const u8,
    };

    pub fn onMarketData(self: Self, msg: MarketDataMessage, book: *OrderBook, order_id_counter: *u16) ?Order {
        return self.vtable.onMarketData(self.ptr, msg, book, order_id_counter);
    }

    pub fn onOrderFill(self: Self, order_id: u16, quantity: u16, price: u16) void {
        self.vtable.onOrderFill(self.ptr, order_id, quantity, price);
    }

    pub fn onOrderRejection(self: Self, order_id: u16, reason: []const u8) void {
        self.vtable.onOrderRejection(self.ptr, order_id, reason);
    }

    pub fn getName(self: Self) []const u8 {
        return self.vtable.getName(self.ptr);
    }
};

/// Market maker strategy - posts quotes around mid price
pub const MarketMaker = struct {
    spread_bps: u32, // Spread in basis points
    order_size: u16,
    last_bid_price: u32,
    last_ask_price: u32,
    orders_sent: u64,
    fills_received: u64,

    pub fn init(spread_bps: u32, order_size: u16) MarketMaker {
        return MarketMaker{
            .spread_bps = spread_bps,
            .order_size = order_size,
            .last_bid_price = 0,
            .last_ask_price = 0,
            .orders_sent = 0,
            .fills_received = 0,
        };
    }

    pub fn strategy(self: *MarketMaker) Strategy {
        return Strategy{
            .ptr = self,
            .vtable = &.{
                .onMarketData = onMarketDataImpl,
                .onOrderFill = onOrderFillImpl,
                .onOrderRejection = onOrderRejectionImpl,
                .getName = getNameImpl,
            },
        };
    }

    fn onMarketDataImpl(ptr: *anyopaque, msg: MarketDataMessage, book: *OrderBook, order_id_counter: *u16) ?Order {
        const self: *MarketMaker = @ptrCast(@alignCast(ptr));
        _ = msg;

        const mid_price = book.midPrice() orelse return null;

        // Calculate quote prices
        const spread_amount = mid_price * @as(f64, @floatFromInt(self.spread_bps)) / 10000.0;
        const bid_price: u32 = @intFromFloat(mid_price - spread_amount);
        const ask_price: u32 = @intFromFloat(mid_price + spread_amount);

        // Alternate between bid and ask orders
        const should_bid = (self.orders_sent % 2) == 0;

        if (should_bid and bid_price != self.last_bid_price) {
            self.last_bid_price = bid_price;
            self.orders_sent += 1;
            order_id_counter.* +%= 1;
            return Order.init(
                order_id_counter.*,
                @intCast(bid_price),
                self.order_size,
                .buy,
                .limit,
            );
        } else if (!should_bid and ask_price != self.last_ask_price) {
            self.last_ask_price = ask_price;
            self.orders_sent += 1;
            order_id_counter.* +%= 1;
            return Order.init(
                order_id_counter.*,
                @intCast(ask_price),
                self.order_size,
                .sell,
                .limit,
            );
        }

        return null;
    }

    fn onOrderFillImpl(ptr: *anyopaque, order_id: u16, quantity: u16, price: u16) void {
        const self: *MarketMaker = @ptrCast(@alignCast(ptr));
        _ = order_id;
        _ = quantity;
        _ = price;
        self.fills_received += 1;
    }

    fn onOrderRejectionImpl(ptr: *anyopaque, order_id: u16, reason: []const u8) void {
        _ = ptr;
        _ = order_id;
        _ = reason;
    }

    fn getNameImpl(ptr: *anyopaque) []const u8 {
        _ = ptr;
        return "MarketMaker";
    }
};

/// Momentum strategy - trades in direction of price movement
pub const MomentumStrategy = struct {
    lookback_periods: usize,
    threshold_bps: u32,
    order_size: u16,
    price_history: [100]u32,
    history_index: usize,
    history_count: usize,
    orders_sent: u64,

    pub fn init(lookback_periods: usize, threshold_bps: u32, order_size: u16) MomentumStrategy {
        return MomentumStrategy{
            .lookback_periods = lookback_periods,
            .threshold_bps = threshold_bps,
            .order_size = order_size,
            .price_history = [_]u32{0} ** 100,
            .history_index = 0,
            .history_count = 0,
            .orders_sent = 0,
        };
    }

    pub fn strategy(self: *MomentumStrategy) Strategy {
        return Strategy{
            .ptr = self,
            .vtable = &.{
                .onMarketData = onMarketDataImpl,
                .onOrderFill = onOrderFillImpl,
                .onOrderRejection = onOrderRejectionImpl,
                .getName = getNameImpl,
            },
        };
    }

    fn onMarketDataImpl(ptr: *anyopaque, msg: MarketDataMessage, book: *OrderBook, order_id_counter: *u16) ?Order {
        const self: *MomentumStrategy = @ptrCast(@alignCast(ptr));
        _ = book;

        // Update price history
        self.price_history[self.history_index] = msg.price;
        self.history_index = (self.history_index + 1) % 100;
        if (self.history_count < 100) {
            self.history_count += 1;
        }

        // Need enough history
        if (self.history_count < self.lookback_periods) {
            return null;
        }

        // Calculate momentum
        const current_price = msg.price;
        const old_idx = if (self.history_index >= self.lookback_periods)
            self.history_index - self.lookback_periods
        else
            100 + self.history_index - self.lookback_periods;

        const old_price = self.price_history[old_idx];
        if (old_price == 0) return null;

        const price_change = @as(i64, @intCast(current_price)) - @as(i64, @intCast(old_price));
        const change_bps = (@as(f64, @floatFromInt(@abs(price_change))) / @as(f64, @floatFromInt(old_price))) * 10000.0;

        // Generate signal if momentum exceeds threshold
        if (change_bps > @as(f64, @floatFromInt(self.threshold_bps))) {
            self.orders_sent += 1;
            order_id_counter.* +%= 1;

            const side: OrderSide = if (price_change > 0) .buy else .sell;
            return Order.init(
                order_id_counter.*,
                @intCast(current_price),
                self.order_size,
                side,
                .market,
            );
        }

        return null;
    }

    fn onOrderFillImpl(ptr: *anyopaque, order_id: u16, quantity: u16, price: u16) void {
        _ = ptr;
        _ = order_id;
        _ = quantity;
        _ = price;
    }

    fn onOrderRejectionImpl(ptr: *anyopaque, order_id: u16, reason: []const u8) void {
        _ = ptr;
        _ = order_id;
        _ = reason;
    }

    fn getNameImpl(ptr: *anyopaque) []const u8 {
        _ = ptr;
        return "Momentum";
    }
};

test "MarketMaker strategy" {
    var mm = MarketMaker.init(10, 100); // 10bps spread, 100 shares
    var strat = mm.strategy();

    try std.testing.expectEqualStrings("MarketMaker", strat.getName());

    var book = OrderBook.init();
    book.addOrder(10000, 100, .buy);
    book.addOrder(10100, 100, .sell);

    const symbol = [_]u8{ 'A', 'A', 'P', 'L', ' ', ' ', ' ', ' ' };
    const msg = MarketDataMessage.init(0, symbol, 10050, 100, .buy);

    var order_id_counter: u16 = 0;
    const order = strat.onMarketData(msg, &book, &order_id_counter);

    try std.testing.expect(order != null);
    try std.testing.expectEqual(@as(u16, 100), order.?.quantity);
}

test "MomentumStrategy" {
    var momentum = MomentumStrategy.init(10, 50, 100);
    var strat = momentum.strategy();

    try std.testing.expectEqualStrings("Momentum", strat.getName());
}
