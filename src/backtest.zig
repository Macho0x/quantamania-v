const std = @import("std");
const data = @import("data.zig");
const strategy = @import("strategy.zig");
const structures = @import("structures.zig");
const execution = @import("execution.zig");
const risk = @import("risk.zig");
const parser = @import("parser.zig");
const MarketDataMessage = data.MarketDataMessage;
const OrderBook = structures.OrderBook;
const Strategy = strategy.Strategy;
const OrderExecutor = execution.OrderExecutor;
const RiskManager = risk.RiskManager;

/// OHLCV bar data
pub const OHLCVBar = struct {
    timestamp: i128,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: u64,

    pub fn toMarketDataMessage(self: OHLCVBar, symbol: [8]u8) MarketDataMessage {
        return MarketDataMessage.init(
            self.timestamp,
            symbol,
            @intFromFloat(self.close * 100.0),
            @intCast(self.volume),
            .buy,
        );
    }
};

/// Backtest statistics
pub const BacktestStats = struct {
    total_pnl: f64,
    total_trades: u64,
    winning_trades: u64,
    losing_trades: u64,
    max_drawdown: f64,
    sharpe_ratio: f64,
    win_rate: f64,
    avg_win: f64,
    avg_loss: f64,

    pub fn calculate(trades: []Trade) BacktestStats {
        var stats = BacktestStats{
            .total_pnl = 0.0,
            .total_trades = trades.len,
            .winning_trades = 0,
            .losing_trades = 0,
            .max_drawdown = 0.0,
            .sharpe_ratio = 0.0,
            .win_rate = 0.0,
            .avg_win = 0.0,
            .avg_loss = 0.0,
        };

        if (trades.len == 0) return stats;

        var total_win: f64 = 0.0;
        var total_loss: f64 = 0.0;
        var returns = std.ArrayList(f64).init(std.heap.page_allocator);
        defer returns.deinit();

        var peak_pnl: f64 = 0.0;
        var cumulative_pnl: f64 = 0.0;

        for (trades) |trade| {
            stats.total_pnl += trade.pnl;
            cumulative_pnl += trade.pnl;

            if (trade.pnl > 0) {
                stats.winning_trades += 1;
                total_win += trade.pnl;
            } else if (trade.pnl < 0) {
                stats.losing_trades += 1;
                total_loss += trade.pnl;
            }

            // Track drawdown
            if (cumulative_pnl > peak_pnl) {
                peak_pnl = cumulative_pnl;
            }
            const drawdown = peak_pnl - cumulative_pnl;
            if (drawdown > stats.max_drawdown) {
                stats.max_drawdown = drawdown;
            }

            returns.append(trade.pnl) catch {};
        }

        // Calculate derived stats
        if (stats.total_trades > 0) {
            stats.win_rate = @as(f64, @floatFromInt(stats.winning_trades)) / @as(f64, @floatFromInt(stats.total_trades)) * 100.0;
        }

        if (stats.winning_trades > 0) {
            stats.avg_win = total_win / @as(f64, @floatFromInt(stats.winning_trades));
        }

        if (stats.losing_trades > 0) {
            stats.avg_loss = total_loss / @as(f64, @floatFromInt(stats.losing_trades));
        }

        // Calculate Sharpe ratio (simplified)
        if (returns.items.len > 1) {
            var mean: f64 = 0.0;
            for (returns.items) |ret| {
                mean += ret;
            }
            mean /= @as(f64, @floatFromInt(returns.items.len));

            var variance: f64 = 0.0;
            for (returns.items) |ret| {
                const diff = ret - mean;
                variance += diff * diff;
            }
            variance /= @as(f64, @floatFromInt(returns.items.len));

            const stddev = @sqrt(variance);
            if (stddev > 0) {
                stats.sharpe_ratio = mean / stddev * @sqrt(252.0); // Annualized
            }
        }

        return stats;
    }

    pub fn print(self: BacktestStats, writer: anytype) !void {
        try writer.print("\n=== Backtest Statistics ===\n", .{});
        try writer.print("Total P&L:       ${d:.2}\n", .{self.total_pnl});
        try writer.print("Total Trades:    {d}\n", .{self.total_trades});
        try writer.print("Winning Trades:  {d}\n", .{self.winning_trades});
        try writer.print("Losing Trades:   {d}\n", .{self.losing_trades});
        try writer.print("Win Rate:        {d:.2}%\n", .{self.win_rate});
        try writer.print("Avg Win:         ${d:.2}\n", .{self.avg_win});
        try writer.print("Avg Loss:        ${d:.2}\n", .{self.avg_loss});
        try writer.print("Max Drawdown:    ${d:.2}\n", .{self.max_drawdown});
        try writer.print("Sharpe Ratio:    {d:.3}\n", .{self.sharpe_ratio});
    }
};

/// Trade record
pub const Trade = struct {
    timestamp: i128,
    symbol: [8]u8,
    side: data.OrderSide,
    quantity: u64,
    price: f64,
    pnl: f64,
};

/// Discrete event simulator for backtesting
pub const DiscreteEventSimulator = struct {
    bars: std.ArrayList(OHLCVBar),
    trades: std.ArrayList(Trade),
    symbol: [8]u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, symbol: [8]u8) DiscreteEventSimulator {
        return DiscreteEventSimulator{
            .bars = std.ArrayList(OHLCVBar).init(allocator),
            .trades = std.ArrayList(Trade).init(allocator),
            .symbol = symbol,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DiscreteEventSimulator) void {
        self.bars.deinit();
        self.trades.deinit();
    }

    pub fn loadFromCsv(self: *DiscreteEventSimulator, filepath: []const u8) !void {
        const file = try std.fs.cwd().openFile(filepath, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var line_buf: [1024]u8 = undefined;

        // Skip header
        _ = try in_stream.readUntilDelimiterOrEof(&line_buf, '\n');

        while (try in_stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
            var it = std.mem.splitScalar(u8, line, ',');

            // timestamp,open,high,low,close,volume
            const timestamp_str = it.next() orelse continue;
            const open_str = it.next() orelse continue;
            const high_str = it.next() orelse continue;
            const low_str = it.next() orelse continue;
            const close_str = it.next() orelse continue;
            const volume_str = it.next() orelse continue;

            const bar = OHLCVBar{
                .timestamp = std.fmt.parseInt(i128, timestamp_str, 10) catch continue,
                .open = std.fmt.parseFloat(f64, open_str) catch continue,
                .high = std.fmt.parseFloat(f64, high_str) catch continue,
                .low = std.fmt.parseFloat(f64, low_str) catch continue,
                .close = std.fmt.parseFloat(f64, close_str) catch continue,
                .volume = std.fmt.parseInt(u64, volume_str, 10) catch continue,
            };

            try self.bars.append(bar);
        }
    }

    pub fn run(self: *DiscreteEventSimulator, strat: Strategy, max_position: i64) !BacktestStats {
        var book = OrderBook.init();
        var rm = try RiskManager.init(self.allocator, max_position);
        defer rm.deinit();

        var executor = try OrderExecutor.init(self.allocator, &rm, true);
        defer executor.deinit();

        var order_id_counter: u16 = 0;
        var position_qty: i64 = 0;
        var entry_price: f64 = 0.0;

        for (self.bars.items) |bar| {
            // Update order book
            const price_cents: u32 = @intFromFloat(bar.close * 100.0);
            book.addOrder(price_cents - 10, 1000, .buy);
            book.addOrder(price_cents + 10, 1000, .sell);

            // Generate market data message
            const msg = bar.toMarketDataMessage(self.symbol);

            // Strategy decision
            if (strat.onMarketData(msg, &book, &order_id_counter)) |order| {
                // Submit and execute order
                _ = executor.submitOrder(order, self.symbol);
                try executor.processOrders(bar.close);

                // Track trades for P&L
                const order_qty: i64 = @intCast(order.quantity);
                const signed_qty = if (order.side == .buy) order_qty else -order_qty;

                // Calculate P&L when closing/reducing position
                var pnl: f64 = 0.0;
                if (position_qty != 0 and
                    ((position_qty > 0 and signed_qty < 0) or
                    (position_qty < 0 and signed_qty > 0)))
                {
                    const closing_qty = @min(@abs(position_qty), @abs(signed_qty));
                    if (position_qty > 0) {
                        pnl = (bar.close - entry_price) * @as(f64, @floatFromInt(closing_qty));
                    } else {
                        pnl = (entry_price - bar.close) * @as(f64, @floatFromInt(closing_qty));
                    }

                    const trade = Trade{
                        .timestamp = bar.timestamp,
                        .symbol = self.symbol,
                        .side = order.side,
                        .quantity = @intCast(closing_qty),
                        .price = bar.close,
                        .pnl = pnl,
                    };
                    try self.trades.append(trade);
                }

                // Update position
                position_qty += signed_qty;
                if (position_qty != 0 and entry_price == 0.0) {
                    entry_price = bar.close;
                } else if (position_qty == 0) {
                    entry_price = 0.0;
                }
            }
        }

        return BacktestStats.calculate(self.trades.items);
    }
};

test "BacktestStats calculation" {
    var trades = [_]Trade{
        Trade{ .timestamp = 0, .symbol = undefined, .side = .buy, .quantity = 100, .price = 100.0, .pnl = 500.0 },
        Trade{ .timestamp = 1, .symbol = undefined, .side = .sell, .quantity = 100, .price = 105.0, .pnl = -200.0 },
        Trade{ .timestamp = 2, .symbol = undefined, .side = .buy, .quantity = 100, .price = 103.0, .pnl = 300.0 },
    };

    const stats = BacktestStats.calculate(&trades);

    try std.testing.expectEqual(@as(u64, 3), stats.total_trades);
    try std.testing.expectEqual(@as(u64, 2), stats.winning_trades);
    try std.testing.expectEqual(@as(u64, 1), stats.losing_trades);
    try std.testing.expect(stats.total_pnl > 500.0);
}
