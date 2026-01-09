// Examples for CCXT-Zig Phase 2: Major Exchanges
//
// These examples demonstrate how to use the implemented exchanges.
// Note: For authenticated endpoints, you need to provide valid API credentials.

const std = @import("std");
const ccxt = @import("main.zig");

// Example 1: Fetching markets from Binance (public endpoint)
pub fn fetchBinanceMarkets(allocator: std.mem.Allocator) !void {
    var auth_config = ccxt.auth.AuthConfig{};
    const binance = try ccxt.binance.create(allocator, auth_config);
    defer binance.deinit();

    const markets = try binance.fetchMarkets();
    defer {
        for (markets) |*market| market.deinit(allocator);
        allocator.free(markets);
    }

    std.debug.print("Binance markets: {d} trading pairs\n", .{markets.len});

    // Print first 5 markets
    for (markets[0..@min(5, markets.len)]) |market| {
        std.debug.print("  {s}: {s}/{s} (active: {})\n", .{
            market.id, market.base, market.quote, market.active,
        });
    }
}

// Example 2: Fetching ticker from Kraken
pub fn fetchKrakenTicker(allocator: std.mem.Allocator) !void {
    var auth_config = ccxt.auth.AuthConfig{};
    const kraken = try ccxt.kraken.create(allocator, auth_config);
    defer kraken.deinit();

    // First fetch markets to get the correct symbol format
    const markets = try kraken.fetchMarkets();
    defer {
        for (markets) |*market| market.deinit(allocator);
        allocator.free(markets);
    }

    // Find BTC/USD market (Kraken uses XBT for Bitcoin)
    const btc_usd = for (markets) |market| {
        if (std.mem.eql(u8, market.base, "XBT") and std.mem.eql(u8, market.quote, "USD")) {
            break market;
        }
    } else return error.SymbolNotFound;

    const ticker = try kraken.fetchTicker(btc_usd.symbol);
    defer ticker.deinit(allocator);

    std.debug.print("Kraken {s} ticker:\n", .{btc_usd.symbol});
    std.debug.print("  Last: ${d:.2}\n", .{ticker.last orelse 0});
    std.debug.print("  High: ${d:.2}\n", .{ticker.high orelse 0});
    std.debug.print("  Low: ${d:.2}\n", .{ticker.low orelse 0});
    std.debug.print("  24h Volume: {d:.2}\n", .{ticker.baseVolume orelse 0});
}

// Example 3: Fetching order book from Coinbase
pub fn fetchCoinbaseOrderBook(allocator: std.mem.Allocator) !void {
    var auth_config = ccxt.auth.AuthConfig{};
    const coinbase = try ccxt.coinbase.create(allocator, auth_config);
    defer coinbase.deinit();

    const orderbook = try coinbase.fetchOrderBook("BTC/USD", 20);
    defer orderbook.deinit(allocator);

    std.debug.print("Coinbase BTC/USD Order Book:\n", .{});
    std.debug.print("  Top 3 Bids:\n", .{});
    for (orderbook.bids[0..@min(3, orderbook.bids.len)]) |bid| {
        std.debug.print("    ${d:.2} x {d:.6}\n", .{ bid.price, bid.amount });
    }

    std.debug.print("  Top 3 Asks:\n", .{});
    for (orderbook.asks[0..@min(3, orderbook.asks.len)]) |ask| {
        std.debug.print("    ${d:.2} x {d:.6}\n", .{ ask.price, ask.amount });
    }
}

// Example 4: Fetching OHLCV data from Bybit
pub fn fetchBybitOHLCV(allocator: std.mem.Allocator) !void {
    var auth_config = ccxt.auth.AuthConfig{};
    const bybit = try ccxt.bybit.create(allocator, auth_config);
    defer bybit.deinit();

    const ohlcv_data = try bybit.fetchOHLCV("BTC/USDT", "1h", null, 24);
    defer allocator.free(ohlcv_data);

    std.debug.print("Bybit BTC/USDT Hourly Candles (last 24):\n", .{});

    for (ohlcv_data) |candle| {
        const dt = try std.fmt.allocPrint(allocator, "{d}", .{candle.timestamp});
        defer allocator.free(dt);

        std.debug.print("  {s}: O: ${d:.2} H: ${d:.2} L: ${d:.2} C: ${d:.2} V: {d:.4}\n", .{
            dt, candle.open, candle.high, candle.low, candle.close, candle.volume,
        });
    }
}

// Example 5: Using the Exchange Registry
pub fn useExchangeRegistry(allocator: std.mem.Allocator) !void {
    var registry = try ccxt.registry.createDefaultRegistry(allocator);
    defer registry.deinit();

    std.debug.print("Available exchanges:\n", .{});
    const names = registry.getNames();
    defer allocator.free(names);

    for (names) |name| {
        if (registry.get(name)) |entry| {
            std.debug.print("  {s}: {s}\n", .{ entry.info.name, entry.info.description });
            std.debug.print("    Spot: {}, Margin: {}, Futures: {}\n", .{
                entry.info.spot_supported,
                entry.info.margin_supported,
                entry.info.futures_supported,
            });
        }
    }

    // Create a testnet Binance instance
    if (registry.get("binance")) |binance_info| {
        if (binance_info.testnet_creator) |creator| {
            var auth_config = ccxt.auth.AuthConfig{
                .apiKey = "your_api_key",
                .apiSecret = "your_api_secret",
            };

            const exchange = try creator(allocator, auth_config);
            defer {
                // Type erasure means we need to cast back - this is a limitation
                // In practice, you'd store the exchange in a typed way
            }
        }
    }
}

// Example 6: Private endpoint with API keys (requires valid credentials)
pub fn fetchPrivateBalance(allocator: std.mem.Allocator) !void {
    // NOTE: Replace with your actual API credentials
    var auth_config = ccxt.auth.AuthConfig{
        .apiKey = try allocator.dupe(u8, "your_api_key_here"),
        .apiSecret = try allocator.dupe(u8, "your_api_secret_here"),
    };
    defer auth_config.deinit(allocator);

    // Example with OKX (requires passphrase)
    var okx_config = ccxt.auth.AuthConfig{
        .apiKey = try allocator.dupe(u8, "your_api_key"),
        .apiSecret = try allocator.dupe(u8, "your_api_secret"),
        .passphrase = try allocator.dupe(u8, "your_passphrase"),
    };
    defer okx_config.deinit(allocator);

    const okx = try ccxt.okx.create(allocator, okx_config);
    defer okx.deinit();

    // This would fetch your balance (requires valid credentials)
    // const balance = try okx.fetchBalance();
    // std.debug.print("OKX USDT balance: {d}\n", .{balance.free});
}

// Example 7: Creating an order (requires valid credentials)
pub fn createTestOrder(allocator: std.mem.Allocator) !void {
    var auth_config = ccxt.auth.AuthConfig{
        .apiKey = try allocator.dupe(u8, "your_api_key"),
        .apiSecret = try allocator.dupe(u8, "your_api_secret"),
    };
    defer auth_config.deinit(allocator);

    const gate = try ccxt.gate.create(allocator, auth_config);
    defer gate.deinit();

    // This would create a test limit order (requires valid credentials)
    // const order = try gate.createOrder("BTC/USDT", "limit", "buy", 0.001, 50000.0, null);
    // std.debug.print("Created order: {s}\n", .{order.id});
}

// Main entry point for examples
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("CCXT-Zig Phase 2 Examples\n", .{});
    std.debug.print("========================\n\n", .{});

    // Run examples (uncomment to test)
    // try fetchBinanceMarkets(allocator);
    // try fetchKrakenTicker(allocator);
    // try fetchCoinbaseOrderBook(allocator);
    // try fetchBybitOHLCV(allocator);
    // try useExchangeRegistry(allocator);

    std.debug.print("Examples ready to use.\n", .{});
    std.debug.print("Uncomment the function calls in main() to run each example.\n", .{});
}
