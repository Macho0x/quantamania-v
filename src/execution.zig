const std = @import("std");
const data = @import("data.zig");
const risk = @import("risk.zig");
const structures = @import("structures.zig");
const parser = @import("parser.zig");
const Order = data.Order;
const OrderSide = data.OrderSide;
const OrderType = data.OrderType;
const OrderStatus = data.OrderStatus;
const RiskManager = risk.RiskManager;
const LockFreeQueue = structures.LockFreeQueue;

/// Order state tracking
pub const OrderState = struct {
    order: Order,
    symbol: [8]u8,
    status: OrderStatus,
    filled_quantity: u16,
    avg_fill_price: f64,
    submit_time: i128,
    fill_time: i128,

    pub fn init(order: Order, symbol: [8]u8) OrderState {
        return OrderState{
            .order = order,
            .symbol = symbol,
            .status = .pending,
            .filled_quantity = 0,
            .avg_fill_price = 0.0,
            .submit_time = parser.nanoTimestamp(),
            .fill_time = 0,
        };
    }
};

/// Order executor with state tracking and risk validation
pub const OrderExecutor = struct {
    const MAX_PENDING_ORDERS = 10000;

    order_states: std.AutoHashMap(u16, OrderState),
    pending_orders: LockFreeQueue(Order, MAX_PENDING_ORDERS),
    risk_manager: *RiskManager,
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    orders_processed: std.atomic.Value(u64),
    orders_filled: std.atomic.Value(u64),
    orders_rejected: std.atomic.Value(u64),
    simulation_mode: bool,

    pub fn init(allocator: std.mem.Allocator, risk_manager: *RiskManager, simulation_mode: bool) !OrderExecutor {
        return OrderExecutor{
            .order_states = std.AutoHashMap(u16, OrderState).init(allocator),
            .pending_orders = LockFreeQueue(Order, MAX_PENDING_ORDERS).init(),
            .risk_manager = risk_manager,
            .allocator = allocator,
            .mutex = std.Thread.Mutex{},
            .orders_processed = std.atomic.Value(u64).init(0),
            .orders_filled = std.atomic.Value(u64).init(0),
            .orders_rejected = std.atomic.Value(u64).init(0),
            .simulation_mode = simulation_mode,
        };
    }

    pub fn deinit(self: *OrderExecutor) void {
        self.order_states.deinit();
    }

    pub fn submitOrder(self: *OrderExecutor, order: Order, symbol: [8]u8) bool {
        if (!self.pending_orders.push(order)) {
            return false;
        }

        self.mutex.lock();
        defer self.mutex.unlock();

        const state = OrderState.init(order, symbol);
        self.order_states.put(order.order_id, state) catch return false;

        return true;
    }

    pub fn processOrders(self: *OrderExecutor, current_price: f64) !void {
        while (self.pending_orders.pop()) |order| {
            try self.processOrder(order, current_price);
        }
    }

    fn processOrder(self: *OrderExecutor, order: Order, current_price: f64) !void {
        _ = self.orders_processed.fetchAdd(1, .monotonic);

        self.mutex.lock();
        var state = self.order_states.get(order.order_id) orelse {
            self.mutex.unlock();
            return;
        };
        self.mutex.unlock();

        // Risk check
        const can_trade = try self.risk_manager.checkOrderRisk(order, state.symbol, current_price);

        if (!can_trade) {
            try self.rejectOrder(order.order_id, "Risk limit exceeded");
            return;
        }

        // Simulate execution
        if (self.simulation_mode) {
            try self.simulateExecution(&state, current_price);
        } else {
            // In real mode, would send to exchange via FIX
            try self.simulateExecution(&state, current_price);
        }

        self.mutex.lock();
        defer self.mutex.unlock();
        try self.order_states.put(order.order_id, state);
    }

    fn simulateExecution(self: *OrderExecutor, state: *OrderState, current_price: f64) !void {
        const order = state.order;

        // Simulate realistic execution logic
        var should_fill = false;
        var fill_price = current_price;

        switch (order.order_type) {
            .market => {
                should_fill = true;
                fill_price = current_price;
            },
            .limit => {
                if (order.side == .buy) {
                    should_fill = current_price <= order.priceAsFloat();
                    fill_price = order.priceAsFloat();
                } else {
                    should_fill = current_price >= order.priceAsFloat();
                    fill_price = order.priceAsFloat();
                }
            },
            .ioc => {
                should_fill = true;
                fill_price = current_price;
            },
            .fok => {
                should_fill = true;
                fill_price = current_price;
            },
        }

        if (should_fill) {
            // Simulate latency (1-10 microseconds)
            const latency_ns = 1000 + @mod(@as(u64, @intCast(parser.nanoTimestamp())), 9000);
            std.time.sleep(latency_ns);

            state.status = .filled;
            state.filled_quantity = order.quantity;
            state.avg_fill_price = fill_price;
            state.fill_time = parser.nanoTimestamp();

            _ = self.orders_filled.fetchAdd(1, .monotonic);

            // Update risk manager
            try self.risk_manager.updatePosition(
                state.symbol,
                order.side,
                @intCast(order.quantity),
                fill_price,
            );
        } else {
            try self.rejectOrder(order.order_id, "Price condition not met");
        }
    }

    fn rejectOrder(self: *OrderExecutor, order_id: u16, reason: []const u8) !void {
        _ = reason;
        _ = self.orders_rejected.fetchAdd(1, .monotonic);

        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.order_states.getPtr(order_id)) |state| {
            state.status = .rejected;
        }
    }

    pub fn getOrderState(self: *OrderExecutor, order_id: u16) ?OrderState {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.order_states.get(order_id);
    }

    pub fn getStats(self: *OrderExecutor) ExecutionStats {
        return ExecutionStats{
            .orders_processed = self.orders_processed.load(.monotonic),
            .orders_filled = self.orders_filled.load(.monotonic),
            .orders_rejected = self.orders_rejected.load(.monotonic),
        };
    }

    pub fn printStats(self: *OrderExecutor, writer: anytype) !void {
        const stats = self.getStats();
        try writer.print("=== Execution Statistics ===\n", .{});
        try writer.print("Orders Processed: {d}\n", .{stats.orders_processed});
        try writer.print("Orders Filled:    {d}\n", .{stats.orders_filled});
        try writer.print("Orders Rejected:  {d}\n", .{stats.orders_rejected});
        if (stats.orders_processed > 0) {
            const fill_rate = @as(f64, @floatFromInt(stats.orders_filled)) / @as(f64, @floatFromInt(stats.orders_processed)) * 100.0;
            try writer.print("Fill Rate:        {d:.2}%\n", .{fill_rate});
        }
    }
};

pub const ExecutionStats = struct {
    orders_processed: u64,
    orders_filled: u64,
    orders_rejected: u64,
};

/// FIX protocol connection (stub for real implementation)
pub const FixConnection = struct {
    connected: bool,

    pub fn init() FixConnection {
        return FixConnection{
            .connected = false,
        };
    }

    pub fn connect(self: *FixConnection, host: []const u8, port: u16) !void {
        _ = host;
        _ = port;
        self.connected = true;
    }

    pub fn sendOrder(self: *FixConnection, order: Order) !void {
        _ = order;
        if (!self.connected) {
            return error.NotConnected;
        }
    }

    pub fn disconnect(self: *FixConnection) void {
        self.connected = false;
    }
};

test "OrderExecutor basic operations" {
    const allocator = std.testing.allocator;

    var rm = try RiskManager.init(allocator, 10000);
    defer rm.deinit();

    var executor = try OrderExecutor.init(allocator, &rm, true);
    defer executor.deinit();

    const symbol = [_]u8{ 'A', 'A', 'P', 'L', ' ', ' ', ' ', ' ' };
    const order = Order.init(1, 10000, 100, .buy, .market);

    const submitted = executor.submitOrder(order, symbol);
    try std.testing.expect(submitted);

    try executor.processOrders(100.0);

    const state = executor.getOrderState(1);
    try std.testing.expect(state != null);
}

test "OrderExecutor rejection" {
    const allocator = std.testing.allocator;

    var rm = try RiskManager.init(allocator, 100);
    defer rm.deinit();

    var executor = try OrderExecutor.init(allocator, &rm, true);
    defer executor.deinit();

    const symbol = [_]u8{ 'A', 'A', 'P', 'L', ' ', ' ', ' ', ' ' };
    const order = Order.init(1, 10000, 500, .buy, .market);

    _ = executor.submitOrder(order, symbol);
    try executor.processOrders(100.0);

    const stats = executor.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.orders_rejected);
}
