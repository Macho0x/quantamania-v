const std = @import("std");

// Import all modules
const data = @import("data.zig");
const structures = @import("structures.zig");
const risk = @import("risk.zig");
const parser = @import("parser.zig");
const strategy = @import("strategy.zig");
const execution = @import("execution.zig");
const metrics = @import("metrics.zig");
const backtest = @import("backtest.zig");

// Re-export module tests
test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(data);
    std.testing.refAllDecls(structures);
    std.testing.refAllDecls(risk);
    std.testing.refAllDecls(parser);
    std.testing.refAllDecls(strategy);
    std.testing.refAllDecls(execution);
    std.testing.refAllDecls(metrics);
    std.testing.refAllDecls(backtest);
}

test "integration: 10k order loop" {
    const allocator = std.testing.allocator;

    var rm = try risk.RiskManager.init(allocator, 100000);
    defer rm.deinit();

    var executor = try execution.OrderExecutor.init(allocator, &rm, true);
    defer executor.deinit();

    var perf_metrics = metrics.PerformanceMetrics.init();

    const symbol = parser.formatSymbol("AAPL");
    var order_id: u16 = 1;

    // Submit and process 10k orders
    var i: usize = 0;
    while (i < 10000) : (i += 1) {
        const side: data.OrderSide = if (i % 2 == 0) .buy else .sell;
        const order = data.Order.init(
            order_id,
            15000, // $150.00
            10,
            side,
            .limit,
        );

        const start = std.time.nanoTimestamp();
        _ = executor.submitOrder(order, symbol);
        
        // Process orders in batches to avoid queue overflow
        if (i % 100 == 0) {
            try executor.processOrders(150.0);
        }
        
        const end = std.time.nanoTimestamp();

        perf_metrics.recordOrderLatency(end - start);
        perf_metrics.recordOrder();

        order_id +%= 1;
    }

    // Process any remaining orders
    try executor.processOrders(150.0);

    const stats = executor.getStats();
    // Should have processed close to 10k orders
    try std.testing.expect(stats.orders_processed >= 9000);

    const p99 = perf_metrics.latency.getP99();
    try std.testing.expect(p99 != null);
}

test "LockFreeQueue concurrent access" {
    var queue = structures.LockFreeQueue(u32, 1000).init();

    const thread1 = try std.Thread.spawn(.{}, struct {
        fn run(q: *structures.LockFreeQueue(u32, 1000)) void {
            var i: u32 = 0;
            while (i < 500) : (i += 1) {
                _ = q.push(i);
            }
        }
    }.run, .{&queue});

    const thread2 = try std.Thread.spawn(.{}, struct {
        fn run(q: *structures.LockFreeQueue(u32, 1000)) void {
            var i: u32 = 500;
            while (i < 1000) : (i += 1) {
                _ = q.push(i);
            }
        }
    }.run, .{&queue});

    thread1.join();
    thread2.join();

    var count: usize = 0;
    while (queue.pop()) |_| {
        count += 1;
    }

    // Should have pushed at least some items
    try std.testing.expect(count > 0);
}

test "OrderBook spread calculation" {
    var book = structures.OrderBook.init();

    book.addOrder(10000, 100, .buy);
    book.addOrder(10010, 100, .buy);
    book.addOrder(10100, 100, .sell);
    book.addOrder(10090, 100, .sell);

    const spread = book.spread();
    try std.testing.expect(spread != null);
    try std.testing.expectEqual(@as(u32, 80), spread.?); // 10090 - 10010

    const spread_bps = book.spreadBps();
    try std.testing.expect(spread_bps != null);
}

test "RiskManager concurrent updates" {
    const allocator = std.testing.allocator;
    var rm = try risk.RiskManager.init(allocator, 10000);
    defer rm.deinit();

    const symbol1 = parser.formatSymbol("AAPL");
    const symbol2 = parser.formatSymbol("GOOG");

    const thread1 = try std.Thread.spawn(.{}, struct {
        fn run(manager: *risk.RiskManager, sym: [8]u8) !void {
            var i: usize = 0;
            while (i < 100) : (i += 1) {
                try manager.updatePosition(sym, .buy, 10, 150.0);
            }
        }
    }.run, .{ &rm, symbol1 });

    const thread2 = try std.Thread.spawn(.{}, struct {
        fn run(manager: *risk.RiskManager, sym: [8]u8) !void {
            var i: usize = 0;
            while (i < 100) : (i += 1) {
                try manager.updatePosition(sym, .buy, 10, 200.0);
            }
        }
    }.run, .{ &rm, symbol2 });

    thread1.join();
    thread2.join();

    const pos1 = rm.getPosition(symbol1);
    const pos2 = rm.getPosition(symbol2);

    try std.testing.expect(pos1 != null);
    try std.testing.expect(pos2 != null);
    try std.testing.expectEqual(@as(i64, 1000), pos1.?.quantity);
    try std.testing.expectEqual(@as(i64, 1000), pos2.?.quantity);
}

test "Strategy order generation" {
    var mm = strategy.MarketMaker.init(10, 100);
    var strat = mm.strategy();

    var book = structures.OrderBook.init();
    book.addOrder(10000, 100, .buy);
    book.addOrder(10100, 100, .sell);

    const symbol = parser.formatSymbol("AAPL");
    const msg = data.MarketDataMessage.init(0, symbol, 10050, 100, .buy);

    var order_id: u16 = 0;
    const order = strat.onMarketData(msg, &book, &order_id);

    try std.testing.expect(order != null);
    try std.testing.expectEqual(@as(u16, 100), order.?.quantity);
}

test "Parser market data round-trip" {
    const symbol = parser.formatSymbol("TSLA");
    const msg = data.MarketDataMessage.init(1234567890, symbol, 25000, 500, .sell);

    var buffer: [25]u8 = undefined;
    try parser.serializeMarketData(msg, &buffer);

    const parsed = try parser.parseMarketData(&buffer);

    try std.testing.expectEqual(msg.timestamp, parsed.timestamp);
    try std.testing.expectEqual(msg.price, parsed.price);
    try std.testing.expectEqual(msg.quantity, parsed.quantity);
    try std.testing.expectEqual(msg.side, parsed.side);
}

test "Metrics percentile accuracy" {
    var tracker = metrics.LatencyTracker.init();

    var i: i64 = 1;
    while (i <= 1000) : (i += 1) {
        tracker.record(i * 1000);
    }

    const p50 = tracker.getP50().?;
    const p99 = tracker.getP99().?;

    // P50 should be around 500k ns
    try std.testing.expect(p50 > 400_000 and p50 < 600_000);
    // P99 should be around 990k ns
    try std.testing.expect(p99 > 900_000 and p99 < 1_000_000);
}

test "Execution order state tracking" {
    const allocator = std.testing.allocator;

    var rm = try risk.RiskManager.init(allocator, 10000);
    defer rm.deinit();

    var executor = try execution.OrderExecutor.init(allocator, &rm, true);
    defer executor.deinit();

    const symbol = parser.formatSymbol("NVDA");
    const order = data.Order.init(42, 50000, 25, .buy, .market);

    _ = executor.submitOrder(order, symbol);
    try executor.processOrders(500.0);

    const state = executor.getOrderState(42);
    try std.testing.expect(state != null);
    try std.testing.expectEqual(@as(u16, 42), state.?.order.order_id);
}
