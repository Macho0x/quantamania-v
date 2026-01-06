const std = @import("std");
const data = @import("data.zig");
const structures = @import("structures.zig");
const risk = @import("risk.zig");
const parser = @import("parser.zig");
const strategy = @import("strategy.zig");
const execution = @import("execution.zig");
const metrics = @import("metrics.zig");
const backtest = @import("backtest.zig");

const Order = data.Order;
const OrderBook = structures.OrderBook;
const MarketDataMessage = data.MarketDataMessage;
const RiskManager = risk.RiskManager;
const OrderExecutor = execution.OrderExecutor;
const Strategy = strategy.Strategy;
const MarketMaker = strategy.MarketMaker;
const MomentumStrategy = strategy.MomentumStrategy;
const PerformanceMetrics = metrics.PerformanceMetrics;
const DiscreteEventSimulator = backtest.DiscreteEventSimulator;

const Config = struct {
    mode: Mode,
    strategy_type: StrategyType,
    symbol: []const u8,
    datafile: ?[]const u8,
    max_position: i64,
    num_messages: usize,

    const Mode = enum {
        realtime,
        backtest,
    };

    const StrategyType = enum {
        marketmaker,
        momentum,
    };
};

fn parseArgs(allocator: std.mem.Allocator) !Config {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    var config = Config{
        .mode = .realtime,
        .strategy_type = .marketmaker,
        .symbol = "AAPL",
        .datafile = null,
        .max_position = 10000,
        .num_messages = 100000,
    };

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--mode")) {
            const mode_str = args.next() orelse return error.MissingArgument;
            if (std.mem.eql(u8, mode_str, "backtest")) {
                config.mode = .backtest;
            } else if (std.mem.eql(u8, mode_str, "realtime")) {
                config.mode = .realtime;
            }
        } else if (std.mem.eql(u8, arg, "--strategy")) {
            const strat_str = args.next() orelse return error.MissingArgument;
            if (std.mem.eql(u8, strat_str, "marketmaker")) {
                config.strategy_type = .marketmaker;
            } else if (std.mem.eql(u8, strat_str, "momentum")) {
                config.strategy_type = .momentum;
            }
        } else if (std.mem.eql(u8, arg, "--symbol")) {
            config.symbol = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--datafile")) {
            config.datafile = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--max-position")) {
            const val_str = args.next() orelse return error.MissingArgument;
            config.max_position = try std.fmt.parseInt(i64, val_str, 10);
        } else if (std.mem.eql(u8, arg, "--messages")) {
            const val_str = args.next() orelse return error.MissingArgument;
            config.num_messages = try std.fmt.parseInt(usize, val_str, 10);
        } else if (std.mem.eql(u8, arg, "--help")) {
            try printHelp();
            std.process.exit(0);
        }
    }

    return config;
}

fn printHelp() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\High-Frequency Trading System
        \\
        \\Usage: hft [options]
        \\
        \\Options:
        \\  --mode <realtime|backtest>    Trading mode (default: realtime)
        \\  --strategy <marketmaker|momentum>  Strategy type (default: marketmaker)
        \\  --symbol <SYMBOL>             Trading symbol (default: AAPL)
        \\  --datafile <path>             CSV file for backtest mode
        \\  --max-position <N>            Max position size (default: 10000)
        \\  --messages <N>                Number of messages to process in realtime (default: 100000)
        \\  --help                        Show this help
        \\
        \\Examples:
        \\  hft --mode realtime --strategy marketmaker --symbol AAPL
        \\  hft --mode backtest --datafile data/AAPL.csv --strategy momentum
        \\
    , .{});
}

fn runRealtime(allocator: std.mem.Allocator, config: Config) !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("=== High-Frequency Trading System ===\n", .{});
    try stdout.print("Mode: Real-time Simulation\n", .{});
    try stdout.print("Strategy: {s}\n", .{@tagName(config.strategy_type)});
    try stdout.print("Symbol: {s}\n", .{config.symbol});
    try stdout.print("Max Position: {d}\n\n", .{config.max_position});

    const symbol = parser.formatSymbol(config.symbol);

    // Initialize components
    var rm = try RiskManager.init(allocator, config.max_position);
    defer rm.deinit();

    var executor = try OrderExecutor.init(allocator, &rm, true);
    defer executor.deinit();

    var book = OrderBook.init();
    var perf_metrics = PerformanceMetrics.init();

    // Create strategy
    var mm = MarketMaker.init(10, 100);
    var momentum = MomentumStrategy.init(20, 25, 100);

    const strat: Strategy = if (config.strategy_type == .marketmaker)
        mm.strategy()
    else
        momentum.strategy();

    var order_id_counter: u16 = 0;

    // Initialize order book
    book.addOrder(14900, 1000, .buy);
    book.addOrder(15100, 1000, .sell);

    var current_price: f64 = 150.0;
    var rng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = rng.random();

    // Main trading loop
    var msg_count: usize = 0;
    const start_time = std.time.nanoTimestamp();

    while (msg_count < config.num_messages) : (msg_count += 1) {
        const loop_start = std.time.nanoTimestamp();

        // Simulate market data
        const price_change = (random.float(f64) - 0.5) * 2.0; // -1 to +1
        current_price += price_change;
        current_price = @max(100.0, @min(200.0, current_price));

        const price_cents: u32 = @intFromFloat(current_price * 100.0);
        const msg = MarketDataMessage.init(
            parser.nanoTimestamp(),
            symbol,
            price_cents,
            @intCast(random.intRangeAtMost(u32, 100, 1000)),
            if (random.boolean()) .buy else .sell,
        );

        perf_metrics.recordMessage();

        // Update order book
        book.addOrder(price_cents - 50, 1000, .buy);
        book.addOrder(price_cents + 50, 1000, .sell);

        // Run strategy
        if (strat.onMarketData(msg, &book, &order_id_counter)) |order| {
            const submit_start = std.time.nanoTimestamp();
            _ = executor.submitOrder(order, symbol);
            try executor.processOrders(current_price);

            const submit_end = std.time.nanoTimestamp();
            perf_metrics.recordOrderLatency(submit_end - submit_start);
            perf_metrics.recordOrder();
        }

        const loop_end = std.time.nanoTimestamp();
        const loop_latency = loop_end - loop_start;

        // Record latency for every 100th message to reduce overhead
        if (msg_count % 100 == 0) {
            perf_metrics.recordOrderLatency(loop_latency);
        }

        // Print progress every 10k messages
        if (msg_count > 0 and msg_count % 10000 == 0) {
            try stdout.print("Processed {d} messages...\n", .{msg_count});
        }
    }

    const end_time = std.time.nanoTimestamp();
    const elapsed_s = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000_000.0;

    // Print results
    try stdout.print("\n", .{});
    try perf_metrics.printSummary(stdout);
    try stdout.print("\n", .{});
    try executor.printStats(stdout);
    try stdout.print("\n", .{});
    try rm.printPositions(stdout);
    try stdout.print("\nTotal elapsed time: {d:.3}s\n", .{elapsed_s});

    // Performance validation
    const msg_per_sec = perf_metrics.throughput.getMessagesPerSecond();
    try stdout.print("\n=== Performance Validation ===\n", .{});

    if (msg_per_sec >= 100000) {
        try stdout.print("✓ Throughput: {d:.0} msg/s (target: 100k+)\n", .{msg_per_sec});
    } else {
        try stdout.print("✗ Throughput: {d:.0} msg/s (target: 100k+)\n", .{msg_per_sec});
    }

    if (perf_metrics.latency.getP99()) |p99| {
        const p99_us = @divFloor(p99, 1000);
        if (p99_us < 100) {
            try stdout.print("✓ P99 Latency: {d}μs (target: <100μs)\n", .{p99_us});
        } else {
            try stdout.print("✗ P99 Latency: {d}μs (target: <100μs)\n", .{p99_us});
        }
    }
}

fn runBacktest(allocator: std.mem.Allocator, config: Config) !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("=== High-Frequency Trading System ===\n", .{});
    try stdout.print("Mode: Backtest\n", .{});
    try stdout.print("Strategy: {s}\n", .{@tagName(config.strategy_type)});
    try stdout.print("Symbol: {s}\n", .{config.symbol});

    if (config.datafile == null) {
        try stdout.print("Error: --datafile required for backtest mode\n", .{});
        return error.MissingDatafile;
    }

    try stdout.print("Data file: {s}\n\n", .{config.datafile.?});

    const symbol = parser.formatSymbol(config.symbol);

    var sim = DiscreteEventSimulator.init(allocator, symbol);
    defer sim.deinit();

    // Load data
    try stdout.print("Loading market data...\n", .{});
    try sim.loadFromCsv(config.datafile.?);
    try stdout.print("Loaded {d} bars\n\n", .{sim.bars.items.len});

    // Create strategy
    var mm = MarketMaker.init(10, 100);
    var momentum = MomentumStrategy.init(20, 25, 100);

    const strat: Strategy = if (config.strategy_type == .marketmaker)
        mm.strategy()
    else
        momentum.strategy();

    // Run backtest
    try stdout.print("Running backtest...\n", .{});
    const stats = try sim.run(strat, config.max_position);

    // Print results
    try stats.print(stdout);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = parseArgs(allocator) catch |err| {
        if (err == error.MissingArgument) {
            try printHelp();
            return;
        }
        return err;
    };

    switch (config.mode) {
        .realtime => try runRealtime(allocator, config),
        .backtest => try runBacktest(allocator, config),
    }
}
