const std = @import("std");
const data = @import("data.zig");
const Order = data.Order;
const OrderSide = data.OrderSide;
const Position = data.Position;

/// Risk manager enforces position limits and exposure constraints
pub const RiskManager = struct {
    const MAX_SYMBOLS = 100;
    const MAX_TOTAL_EXPOSURE = 1_000_000_00; // $1M in cents

    positions: std.AutoHashMap([8]u8, Position),
    max_position_per_symbol: i64,
    max_total_exposure: i64,
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_position_per_symbol: i64) !RiskManager {
        return RiskManager{
            .positions = std.AutoHashMap([8]u8, Position).init(allocator),
            .max_position_per_symbol = max_position_per_symbol,
            .max_total_exposure = MAX_TOTAL_EXPOSURE,
            .mutex = std.Thread.Mutex{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RiskManager) void {
        self.positions.deinit();
    }

    pub fn checkOrderRisk(self: *RiskManager, order: Order, symbol: [8]u8, current_price: f64) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Get or create position
        const pos = self.positions.get(symbol) orelse Position.init(symbol, self.max_position_per_symbol);

        // Calculate new position
        const order_qty: i64 = @intCast(order.quantity);
        const new_qty = if (order.side == .buy)
            pos.quantity + order_qty
        else
            pos.quantity - order_qty;

        // Check position limits
        if (@abs(new_qty) > self.max_position_per_symbol) {
            return false;
        }

        // Check total exposure
        const total_exposure = try self.calculateTotalExposure(current_price);
        const order_value = current_price * @as(f64, @floatFromInt(order.quantity));

        if (total_exposure + order_value > @as(f64, @floatFromInt(self.max_total_exposure)) / 100.0) {
            return false;
        }

        return true;
    }

    pub fn updatePosition(self: *RiskManager, symbol: [8]u8, side: OrderSide, quantity: i64, price: f64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var pos = self.positions.get(symbol) orelse Position.init(symbol, self.max_position_per_symbol);
        pos.updatePosition(side, quantity, price);
        try self.positions.put(symbol, pos);
    }

    pub fn getPosition(self: *RiskManager, symbol: [8]u8) ?Position {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.positions.get(symbol);
    }

    pub fn calculateTotalExposure(self: *RiskManager, current_price: f64) !f64 {
        var total: f64 = 0.0;
        var it = self.positions.valueIterator();

        while (it.next()) |pos| {
            total += @abs(@as(f64, @floatFromInt(pos.quantity))) * current_price;
        }

        return total;
    }

    pub fn getTotalPnL(self: *RiskManager, current_prices: std.AutoHashMap([8]u8, f64)) f64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var total_pnl: f64 = 0.0;
        var it = self.positions.iterator();

        while (it.next()) |entry| {
            var pos = entry.value_ptr.*;
            if (current_prices.get(entry.key_ptr.*)) |price| {
                pos.calculateUnrealizedPnL(price);
            }
            total_pnl += pos.totalPnL();
        }

        return total_pnl;
    }

    pub fn printPositions(self: *RiskManager, writer: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try writer.print("=== Positions ===\n", .{});

        var it = self.positions.iterator();
        while (it.next()) |entry| {
            const pos = entry.value_ptr.*;
            const symbol_str = std.mem.sliceTo(&pos.symbol, 0);

            try writer.print("Symbol: {s:<8} | Qty: {d:>8} | Avg: ${d:>8.2} | Realized: ${d:>10.2} | Unrealized: ${d:>10.2}\n", .{
                symbol_str,
                pos.quantity,
                pos.avg_price,
                pos.realized_pnl,
                pos.unrealized_pnl,
            });
        }
    }
};

test "RiskManager position limits" {
    const allocator = std.testing.allocator;
    var rm = try RiskManager.init(allocator, 1000);
    defer rm.deinit();

    const symbol = [_]u8{ 'A', 'A', 'P', 'L', ' ', ' ', ' ', ' ' };

    // First order should pass
    const order1 = Order.init(1, 10000, 500, .buy, .limit);
    const can_trade1 = try rm.checkOrderRisk(order1, symbol, 100.0);
    try std.testing.expect(can_trade1);

    // Update position
    try rm.updatePosition(symbol, .buy, 500, 100.0);

    // Order exceeding limit should fail
    const order2 = Order.init(2, 10000, 600, .buy, .limit);
    const can_trade2 = try rm.checkOrderRisk(order2, symbol, 100.0);
    try std.testing.expect(!can_trade2);

    // Order within limit should pass
    const order3 = Order.init(3, 10000, 400, .buy, .limit);
    const can_trade3 = try rm.checkOrderRisk(order3, symbol, 100.0);
    try std.testing.expect(can_trade3);
}

test "RiskManager exposure calculation" {
    const allocator = std.testing.allocator;
    var rm = try RiskManager.init(allocator, 10000);
    defer rm.deinit();

    const symbol1 = [_]u8{ 'A', 'A', 'P', 'L', ' ', ' ', ' ', ' ' };
    const symbol2 = [_]u8{ 'G', 'O', 'O', 'G', ' ', ' ', ' ', ' ' };

    try rm.updatePosition(symbol1, .buy, 100, 150.0);
    try rm.updatePosition(symbol2, .buy, 50, 200.0);

    const exposure = try rm.calculateTotalExposure(160.0);
    try std.testing.expect(exposure > 20000.0);
}
