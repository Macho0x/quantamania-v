// CCXT-Zig Performance Benchmarks - Phase 2: Major Exchanges
//
// This benchmark module measures the performance of key operations
// across all implemented exchanges.

const std = @import("std");
const ccxt = @import("ccxt_zig");

// Benchmark configuration
const BENCHMARK_ITERATIONS = 1000;
const WARMUP_ITERATIONS = 100;

// Timer utilities
const BenchmarkTimer = struct {
    start_time: i64,
    end_time: i64,

    fn start() BenchmarkTimer {
        return .{
            .start_time = std.time.nanoTimestamp(),
            .end_time = 0,
        };
    }

    fn stop(self: *BenchmarkTimer) void {
        self.end_time = std.time.nanoTimestamp();
    }

    fn elapsed_ns(self: *BenchmarkTimer) i64 {
        return self.end_time - self.start_time;
    }

    fn elapsed_us(self: *BenchmarkTimer) f64 {
        return @as(f64, @floatFromInt(self.elapsed_ns())) / 1000.0;
    }

    fn elapsed_ms(self: *BenchmarkTimer) f64 {
        return @as(f64, @floatFromInt(self.elapsed_ns())) / 1_000_000.0;
    }
};

// Benchmark result structure
const BenchmarkResult = struct {
    name: []const u8,
    iterations: usize,
    total_ns: i64,
    avg_ns: f64,
    min_ns: i64,
    max_ns: i64,
    stddev_ns: f64,

    fn format(self: *const BenchmarkResult, writer: anytype) !void {
        const avg_us = self.avg_ns / 1000.0;
        const total_ms = @as(f64, @floatFromInt(self.total_ns)) / 1_000_000.0;
        const stddev_us = self.stddev_ns / 1000.0;

        try writer.print(
            "{s:30} | {d:6}x | {d:8.2} us/op | {d:8.2} ms total | {d:8.2} us stddev\n",
            .{
                self.name,
                self.iterations,
                avg_us,
                total_ms,
                stddev_us,
            },
        );
    }
};

// Benchmark result collection
const BenchmarkSuite = struct {
    allocator: std.mem.Allocator,
    results: std.ArrayList(BenchmarkResult),

    fn init(allocator: std.mem.Allocator) BenchmarkSuite {
        return .{
            .allocator = allocator,
            .results = std.ArrayList(BenchmarkResult).init(allocator),
        };
    }

    fn deinit(self: *BenchmarkSuite) void {
        self.results.deinit();
    }

    fn addResult(self: *BenchmarkSuite, result: BenchmarkResult) !void {
        try self.results.append(result);
    }

    fn printResults(self: *const BenchmarkSuite) !void {
        const writer = std.io.getStdOut().writer();

        try writer.print("\n{:-^80}\n", .{" Benchmark Results "});
        try writer.print("{s:30} | {s:7} | {s:11} | {s:12} | {s:12}\n", .{
            "Test Name", "Iterations", "Avg Time", "Total Time", "Std Dev"});
        try writer.print("{s:-+80}\n", .{"-" ** 80});

        for (self.results.items) |result| {
            var r = result;
            try r.format(writer);
        }
    }
};

// Run a single benchmark
fn runBenchmark(
    allocator: std.mem.Allocator,
    name: []const u8,
    iterations: usize,
    warmup: usize,
    func: fn () anyerror!void,
) !BenchmarkResult {
    var times = std.ArrayList(i64).init(allocator);
    defer times.deinit();

    // Warmup phase
    for (0..warmup) |_| {
        try func();
    }

    // Benchmark phase
    for (0..iterations) |_| {
        var timer = BenchmarkTimer.start();
        try func();
        timer.stop();
        try times.append(timer.elapsed_ns());
    }

    // Calculate statistics
    var total_ns: i64 = 0;
    var min_ns: i64 = std.math.maxInt(i64);
    var max_ns: i64 = 0;

    for (times.items) |t| {
        total_ns += t;
        if (t < min_ns) min_ns = t;
        if (t > max_ns) max_ns = t;
    }

    const avg_ns = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(iterations));

    // Calculate standard deviation
    var sum_sq_diff: f64 = 0;
    for (times.items) |t| {
        const diff = @as(f64, @floatFromInt(t)) - avg_ns;
        sum_sq_diff += diff * diff;
    }
    const stddev_ns = std.math.sqrt(sum_sq_diff / @as(f64, @floatFromInt(iterations)));

    return .{
        .name = name,
        .iterations = iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .stddev_ns = stddev_ns,
    };
}

// ==================== Benchmark Functions ====================

fn benchmarkMarketParsing(allocator: std.mem.Allocator) !void {
    const mock_ticker = 
\\{
\\  "symbol": "BTCUSDT",
\\  "price": "50000.00",
\\  "highPrice": "52000.00",
\\  "lowPrice": "48000.00",
\\  "bidPrice": "49999.99",
\\  "askPrice": "50000.01",
\\  "volume": "1000.00"
\\};

    var auth_config = ccxt.auth.AuthConfig{};
    const binance = try ccxt.binance.create(allocator, auth_config);
    defer binance.deinit();

    const parser = &binance.base.json_parser;
    const parsed = try parser.parse(mock_ticker);

    // Parse ticker to test parsing performance
    const ticker = try binance.parseTicker(parsed.value, "BTC/USDT");
    ticker.deinit(allocator);
}

fn benchmarkOrderBookParsing(allocator: std.mem.Allocator) !void {
    const mock_book = 
\\{
\\  "bids": [
\\    ["50000.00", "1.5"],
\\    ["49999.99", "2.0"],
\\    ["49999.98", "3.0"],
\\    ["49999.97", "1.0"],
\\    ["49999.96", "2.5"]
\\  ],
\\  "asks": [
\\    ["50000.01", "1.0"],
\\    ["50000.02", "2.5"],
\\    ["50000.03", "1.5"],
\\    ["50000.04", "3.0"],
\\    ["50000.05", "2.0"]
\\  ],
\\  "timestamp": 1705315800000
\\};

    var auth_config = ccxt.auth.AuthConfig{};
    const binance = try ccxt.binance.create(allocator, auth_config);
    defer binance.deinit();

    const parser = &binance.base.json_parser;
    const parsed = try parser.parse(mock_book);

    const orderbook = try binance.parseOrderBook(parsed.value, "BTC/USDT");
    orderbook.deinit(allocator);
}

fn benchmarkOHLCVParsing(allocator: std.mem.Allocator) !void {
    const mock_ohlcv = 
\\[
\\  [1705315200000, "49000.00", "50000.00", "48000.00", "49500.00", "1000.00"],
\\  [1705318800000, "49500.00", "51000.00", "49000.00", "50000.00", "1200.00"],
\\  [1705322400000, "50000.00", "50500.00", "49500.00", "50200.00", "800.00"],
\\  [1705326000000, "50200.00", "51000.00", "50000.00", "50800.00", "1500.00"],
\\  [1705329600000, "50800.00", "51500.00", "50500.00", "51200.00", "2000.00"]
\\];

    var auth_config = ccxt.auth.AuthConfig{};
    const binance = try ccxt.binance.create(allocator, auth_config);
    defer binance.deinit();

    const parser = &binance.base.json_parser;
    const parsed = try parser.parse(mock_ohlcv);

    const ohlcvs = try binance.parseOHLCV(parsed.value, "BTC/USDT");
    defer allocator.free(ohlcvs);
}

fn benchmarkHMACSignature(allocator: std.mem.Allocator) !void {
    const key = "test_api_secret_key_that_is_long_enough";
    const message = "GET\napi.binance.com\n/api/v3/order\nsymbol=BTCUSDT&timestamp=1234567890";

    const signature = try ccxt.crypto.Signer.hmacSha256Hex(key, message);
    allocator.free(signature);
}

fn benchmarkBase64Encoding(allocator: std.mem.Allocator) !void {
    const data = "Hello, World! This is a test string for base64 encoding performance.";
    const encoded = try ccxt.crypto.base64Encode(allocator, data);
    defer allocator.free(encoded);
}

fn benchmarkJSONParsing(allocator: std.mem.Allocator) !void {
    const json_str = 
\\{
\\  "id": "btcusdt",
\\  "symbol": "BTC/USDT",
\\  "base": "BTC",
\\  "quote": "USDT",
\\  "active": true,
\\  "precision": {
\\    "amount": 8,
\\    "price": 2
\\  },
\\  "limits": {
\\    "amount": {
\\      "min": 0.001,
\\      "max": 1000
\\    },
\\    "price": {
\\      "min": 0.01,
\\      "max": 1000000
\\    }
\\  },
\\  "info": {}
\\};

    const parser = ccxt.json.JsonParser.init(allocator);
    const parsed = try parser.parse(json_str);
    parsed.deinit();
}

fn benchmarkExchangeRegistryLookup(allocator: std.mem.Allocator) !void {
    var registry = try ccxt.registry.createDefaultRegistry(allocator);
    defer registry.deinit();

    const exchanges = [_][]const u8{ "binance", "kraken", "coinbase", "bybit", "okx", "gate", "huobi" };

    for (exchanges) |name| {
        _ = registry.get(name);
    }
}

fn benchmarkDecimalConversion(allocator: std.mem.Allocator) !void {
    const str = "12345.67890123";
    const decimal = try ccxt.types.Decimal.fromString(allocator, str);
    decimal.deinit(allocator);
}

// ==================== Main Benchmark Runner ====================

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("\n{:=^80}\n", .{" CCXT-Zig Performance Benchmarks "});
    std.debug.print("Phase 2: Major Exchanges Implementation\n", .{});
    std.debug.print("Iterations: {d}, Warmup: {d}\n", .{ BENCHMARK_ITERATIONS, WARMUP_ITERATIONS });
    std.debug.print("{:=^80}\n\n", .{"-" ** 80});

    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    // Run benchmarks
    suite.addResult(try runBenchmark(allocator, "Market Parsing", BENCHMARK_ITERATIONS, WARMUP_ITERATIONS, benchmarkMarketParsing));
    suite.addResult(try runBenchmark(allocator, "OrderBook Parsing", BENCHMARK_ITERATIONS, WARMUP_ITERATIONS, benchmarkOrderBookParsing));
    suite.addResult(try runBenchmark(allocator, "OHLCV Parsing", BENCHMARK_ITERATIONS, WARMUP_ITERATIONS, benchmarkOHLCVParsing));
    suite.addResult(try runBenchmark(allocator, "HMAC-SHA256 Signature", BENCHMARK_ITERATIONS, WARMUP_ITERATIONS, benchmarkHMACSignature));
    suite.addResult(try runBenchmark(allocator, "Base64 Encoding", BENCHMARK_ITERATIONS, WARMUP_ITERATIONS, benchmarkBase64Encoding));
    suite.addResult(try runBenchmark(allocator, "JSON Parsing", BENCHMARK_ITERATIONS, WARMUP_ITERATIONS, benchmarkJSONParsing));
    suite.addResult(try runBenchmark(allocator, "Registry Lookup", BENCHMARK_ITERATIONS, WARMUP_ITERATIONS, benchmarkExchangeRegistryLookup));
    suite.addResult(try runBenchmark(allocator, "Decimal Conversion", BENCHMARK_ITERATIONS, WARMUP_ITERATIONS, benchmarkDecimalConversion));

    // Print results
    try suite.printResults();

    // Print summary
    std.debug.print("\n{:=^80}\n", .{" Summary "});
    var total_avg_ns: f64 = 0;
    for (suite.results.items) |result| {
        total_avg_ns += result.avg_ns;
    }
    const total_ops_per_sec = @as(f64, @floatFromInt(suite.results.items.len)) * @as(f64, @floatFromInt(BENCHMARK_ITERATIONS)) / (total_avg_ns / 1_000_000_000);
    std.debug.print("Total operations per second: {d:.0f}\n", .{total_ops_per_sec});
    std.debug.print("Average time per operation: {d:.2} us\n", .{total_avg_ns / @as(f64, @floatFromInt(suite.results.items.len)) / 1000.0});
}
