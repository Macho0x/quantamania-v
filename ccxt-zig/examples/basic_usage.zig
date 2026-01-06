const std = @import("std");
const ccxt = @import("../src/main.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("=== CCXT Zig Examples ===\n\n", .{});
    
    // Example 1: Fetch markets from Binance
    try exampleBinanceMarkets(allocator);
    
    // Example 2: Fetch ticker from Kraken
    try exampleKrakenTicker(allocator);
    
    // Example 3: Fetch order book from Coinbase
    try exampleCoinbaseOrderBook(allocator);
    
    // Example 4: Fetch OHLCV from Binance
    try exampleBinanceOHLCV(allocator);
}

fn exampleBinanceMarkets(allocator: std.mem.Allocator) !void {
    std.debug.print("--- Example 1: Binance Markets ---\n", .{});
    
    const auth_config = ccxt.auth.AuthConfig{};
    const exchange = try ccxt.binance.BinanceExchange.create(allocator, auth_config);
    defer exchange.destroy();
    
    const markets = try exchange.fetchMarkets();
    defer {
        for (markets) |*market| {
            var mut_market = market.*;
            mut_market.deinit(allocator);
        }
        allocator.free(markets);
    }
    
    std.debug.print("Fetched {} markets from Binance\n", .{markets.len});
    
    // Print first 5 markets
    const limit = @min(5, markets.len);
    for (markets[0..limit]) |market| {
        std.debug.print("  {s}: {s}/{s} (active: {})\n", .{
            market.id,
            market.base,
            market.quote,
            market.active,
        });
    }
    
    std.debug.print("\n", .{});
}

fn exampleKrakenTicker(allocator: std.mem.Allocator) !void {
    std.debug.print("--- Example 2: Kraken Ticker ---\n", .{});
    
    const auth_config = ccxt.auth.AuthConfig{};
    const exchange = try ccxt.kraken.KrakenExchange.create(allocator, auth_config);
    defer exchange.destroy();
    
    const ticker = try exchange.fetchTicker("BTC/USDT");
    defer {
        var mut_ticker = ticker;
        mut_ticker.deinit(allocator);
    }
    
    std.debug.print("Symbol: {s}\n", .{ticker.symbol});
    std.debug.print("Last Price: {?d:.2}\n", .{ticker.last});
    std.debug.print("High (24h): {?d:.2}\n", .{ticker.high});
    std.debug.print("Low (24h): {?d:.2}\n", .{ticker.low});
    std.debug.print("Bid: {?d:.2}\n", .{ticker.bid});
    std.debug.print("Ask: {?d:.2}\n", .{ticker.ask});
    std.debug.print("Volume (24h): {?d:.2}\n", .{ticker.baseVolume});
    
    std.debug.print("\n", .{});
}

fn exampleCoinbaseOrderBook(allocator: std.mem.Allocator) !void {
    std.debug.print("--- Example 3: Coinbase Order Book ---\n", .{});
    
    const auth_config = ccxt.auth.AuthConfig{};
    const exchange = try ccxt.coinbase.CoinbaseExchange.create(allocator, auth_config);
    defer exchange.destroy();
    
    var order_book = try exchange.fetchOrderBook("BTC/USD", 10);
    defer order_book.deinit(allocator);
    
    std.debug.print("Symbol: {s}\n", .{order_book.symbol});
    std.debug.print("Timestamp: {d}\n", .{order_book.timestamp});
    
    std.debug.print("\nTop 5 Bids:\n", .{});
    const bid_limit = @min(5, order_book.bids.items.len);
    for (order_book.bids.items[0..bid_limit]) |bid| {
        std.debug.print("  {d:.2} @ {d:.8}\n", .{ bid[1], bid[0] });
    }
    
    std.debug.print("\nTop 5 Asks:\n", .{});
    const ask_limit = @min(5, order_book.asks.items.len);
    for (order_book.asks.items[0..ask_limit]) |ask| {
        std.debug.print("  {d:.2} @ {d:.8}\n", .{ ask[1], ask[0] });
    }
    
    std.debug.print("\n", .{});
}

fn exampleBinanceOHLCV(allocator: std.mem.Allocator) !void {
    std.debug.print("--- Example 4: Binance OHLCV ---\n", .{});
    
    const auth_config = ccxt.auth.AuthConfig{};
    const exchange = try ccxt.binance.BinanceExchange.create(allocator, auth_config);
    defer exchange.destroy();
    
    const ohlcv = try exchange.fetchOHLCV("BTC/USDT", .{ ._1h }, null, 10);
    defer allocator.free(ohlcv);
    
    std.debug.print("Fetched {} candles for BTC/USDT (1h)\n\n", .{ohlcv.len});
    
    std.debug.print("Timestamp           | Open      | High      | Low       | Close     | Volume\n", .{});
    std.debug.print("------------------------------------------------------------------------------------\n", .{});
    
    for (ohlcv) |candle| {
        std.debug.print("{d:19} | {d:9.2} | {d:9.2} | {d:9.2} | {d:9.2} | {d:.2}\n", .{
            candle.timestamp,
            candle.open,
            candle.high,
            candle.low,
            candle.close,
            candle.volume,
        });
    }
    
    std.debug.print("\n", .{});
}
