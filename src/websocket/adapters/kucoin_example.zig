// KuCoin WebSocket Adapter Example Usage
// Demonstrates integration with spot and futures trading

const std = @import("std");
const allocator = std.heap.page_allocator;

const kucoin_adapter = @import("kucoin.zig");
const KucoinWebSocketAdapter = kucoin_adapter.KucoinWebSocketAdapter;
const types = @import("../types.zig");

// Example callback functions
fn tickerCallback(data: []const u8) void {
    std.debug.print("🔔 Ticker Update: {s}\n", .{data});
}

fn orderbookCallback(data: []const u8) void {
    std.debug.print("📊 OrderBook Update: {s}\n", .{data});
}

fn tradesCallback(data: []const u8) void {
    std.debug.print("💹 Trade Update: {s}\n", .{data});
}

fn ohlcvCallback(data: []const u8) void {
    std.debug.print("🕯️ OHLCV Update: {s}\n", .{data});
}

fn balanceCallback(data: []const u8) void {
    std.debug.print("💰 Balance Update: {s}\n", .{data});
}

fn ordersCallback(data: []const u8) void {
    std.debug.print("📋 Order Update: {s}\n", .{data});
}

// Example: Basic ticker subscription
pub fn exampleBasicTicker() !void {
    std.debug.print("=== KuCoin WebSocket Example: Basic Ticker ===\n");
    
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    // Connect to WebSocket
    try adapter.connect();
    std.debug.print("✅ Connected to KuCoin WebSocket\n");
    
    // Subscribe to ticker
    try adapter.watchTicker("BTC-USDT", tickerCallback);
    std.debug.print("📊 Subscribed to BTC-USDT ticker\n");
    
    // Listen for messages (in real app, this would be in a loop)
    std.debug.print("🎧 Listening for ticker updates...\n");
}

// Example: Multiple market data subscriptions
pub fn exampleMarketDataSubscriptions() !void {
    std.debug.print("=== KuCoin WebSocket Example: Market Data ===\n");
    
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    try adapter.connect();
    
    // Subscribe to multiple tickers
    const symbols = &[_][]const u8{ "BTC-USDT", "ETH-USDT", "ADA-USDT" };
    for (symbols) |symbol| {
        try adapter.watchTicker(symbol, tickerCallback);
        std.debug.print("📊 Subscribed to {s} ticker\n", .{symbol});
    }
    
    // Subscribe to orderbooks
    try adapter.watchOrderBook("BTC-USDT", 20, orderbookCallback);
    std.debug.print("📊 Subscribed to BTC-USDT orderbook (20 levels)\n");
    
    try adapter.watchOrderBook("ETH-USDT", 100, orderbookCallback);
    std.debug.print("📊 Subscribed to ETH-USDT orderbook (100 levels)\n");
    
    // Subscribe to trades
    try adapter.watchTrades("BTC-USDT", tradesCallback);
    std.debug.print("💹 Subscribed to BTC-USDT trades\n");
    
    // Subscribe to OHLCV data
    try adapter.watchOHLCV("BTC-USDT", "1hour", ohlcvCallback);
    std.debug.print("🕯️ Subscribed to BTC-USDT 1hour candles\n");
    
    try adapter.watchOHLCV("BTC-USDT", "4hour", ohlcvCallback);
    std.debug.print("🕯️ Subscribed to BTC-USDT 4hour candles\n");
    
    std.debug.print("🎧 Listening for market data updates...\n");
}

// Example: Authenticated trading
pub fn exampleAuthenticatedTrading() !void {
    std.debug.print("=== KuCoin WebSocket Example: Authenticated Trading ===\n");
    
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    // Authenticate with API credentials
    const api_key = "your_api_key";
    const api_secret = "your_api_secret";
    const passphrase = "your_passphrase";
    
    try adapter.authenticate(api_key, api_secret, passphrase);
    std.debug.print("🔐 Authenticated with KuCoin API\n");
    
    try adapter.connect();
    
    // Subscribe to balance updates
    try adapter.watchBalance(balanceCallback);
    std.debug.print("💰 Subscribed to balance updates\n");
    
    // Subscribe to order updates for specific symbols
    try adapter.watchOrders("BTC-USDT", ordersCallback);
    std.debug.print("📋 Subscribed to BTC-USDT order updates\n");
    
    try adapter.watchOrders("ETH-USDT", ordersCallback);
    std.debug.print("📋 Subscribed to ETH-USDT order updates\n");
    
    std.debug.print("🎧 Listening for authenticated updates...\n");
}

// Example: Batch subscription
pub fn exampleBatchSubscription() !void {
    std.debug.print("=== KuCoin WebSocket Example: Batch Subscription ===\n");
    
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    try adapter.connect();
    
    const batch_requests = &[_]KucoinWebSocketAdapter.BatchSubscriptionRequest{
        .{
            .subscription_type = .ticker,
            .symbol = "BTC-USDT",
            .timeframe = null,
            .limit = null,
            .callback = tickerCallback,
        },
        .{
            .subscription_type = .orderbook,
            .symbol = "BTC-USDT",
            .timeframe = null,
            .limit = 20,
            .callback = orderbookCallback,
        },
        .{
            .subscription_type = .trades,
            .symbol = "BTC-USDT",
            .timeframe = null,
            .limit = null,
            .callback = tradesCallback,
        },
        .{
            .subscription_type = .ohlcv,
            .symbol = "BTC-USDT",
            .timeframe = "1hour",
            .limit = null,
            .callback = ohlcvCallback,
        },
        .{
            .subscription_type = .ohlcv,
            .symbol = "ETH-USDT",
            .timeframe = "1hour",
            .limit = null,
            .callback = ohlcvCallback,
        },
    };
    
    try adapter.batchSubscribe(batch_requests);
    std.debug.print("📦 Batch subscribed to 5 channels\n");
    
    std.debug.print("🎧 Listening for batch updates...\n");
}

// Example: Futures trading
pub fn exampleFuturesTrading() !void {
    std.debug.print("=== KuCoin WebSocket Example: Futures Trading ===\n");
    
    // Note: This would require connecting to futures WebSocket endpoint
    // and using futures-specific symbols like "BTC-USD-SWAP"
    
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    try adapter.connect();
    
    // Futures ticker
    try adapter.watchTicker("BTC-USD-SWAP", tickerCallback);
    std.debug.print("📊 Subscribed to BTC futures ticker\n");
    
    // Futures orderbook
    try adapter.watchOrderBook("BTC-USD-SWAP", 20, orderbookCallback);
    std.debug.print("📊 Subscribed to BTC futures orderbook\n");
    
    // Futures trades
    try adapter.watchTrades("BTC-USD-SWAP", tradesCallback);
    std.debug.print("💹 Subscribed to BTC futures trades\n");
    
    std.debug.print("🎧 Listening for futures updates...\n");
}

// Example: SandBox testing
pub fn exampleSandboxTesting() !void {
    std.debug.print("=== KuCoin WebSocket Example: Sandbox Testing ===\n");
    
    // Use sandbox/testnet environment for testing
    const adapter = try KucoinWebSocketAdapter.init(allocator, true);
    defer adapter.deinit();
    
    try adapter.connect();
    
    // Subscribe to ticker in sandbox
    try adapter.watchTicker("BTC-USDT", tickerCallback);
    std.debug.print("🧪 Subscribed to BTC-USDT ticker in sandbox\n");
    
    std.debug.print("🎧 Listening for sandbox updates...\n");
}

// Example: Message handling loop
pub fn exampleMessageHandling() !void {
    std.debug.print("=== KuCoin WebSocket Example: Message Handling ===\n");
    
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    try adapter.connect();
    
    // Set up subscriptions
    try adapter.watchTicker("BTC-USDT", tickerCallback);
    try adapter.watchOrderBook("BTC-USDT", 20, orderbookCallback);
    
    std.debug.print("🎧 Starting message handling loop...\n");
    
    // In a real application, this would be in a continuous loop
    // with proper error handling and reconnection logic
    var running = true;
    var message_count: usize = 0;
    
    while (running and message_count < 10) {
        // Receive and handle messages
        if (adapter.isConnected()) {
            const message = try adapter.receiveMessage();
            defer allocator.free(message);
            
            try adapter.handleMessage(message);
            message_count += 1;
            
            std.debug.print("📨 Processed message #{d}\n", .{message_count});
        } else {
            std.debug.print("⚠️  WebSocket disconnected, attempting reconnect...\n");
            // In real app, implement reconnection logic here
            try adapter.connect();
        }
        
        // Sleep briefly between messages (in real app, use proper event loop)
        std.time.sleep(100 * 1_000_000); // 100ms
    }
    
    std.debug.print("✅ Message handling completed\n");
}

// Example: Unsubscribe operations
pub fn exampleUnsubscribeOperations() !void {
    std.debug.print("=== KuCoin WebSocket Example: Unsubscribe Operations ===\n");
    
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    try adapter.connect();
    
    // Subscribe to multiple channels
    try adapter.watchTicker("BTC-USDT", tickerCallback);
    try adapter.watchTicker("ETH-USDT", tickerCallback);
    try adapter.watchOrderBook("BTC-USDT", 20, orderbookCallback);
    try adapter.watchTrades("BTC-USDT", tradesCallback);
    
    std.debug.print("📊 Created 4 subscriptions\n");
    
    // Unsubscribe from specific channels
    try adapter.unsubscribe("ticker_BTC-USDT");
    std.debug.print("🗑️  Unsubscribed from BTC-USDT ticker\n");
    
    try adapter.unsubscribe("orderbook_BTC-USDT_20");
    std.debug.print("🗑️  Unsubscribed from BTC-USDT orderbook\n");
    
    // Clean up remaining subscriptions
    var iter = adapter.subscriptions.iterator();
    while (iter.next()) |entry| {
        try adapter.unsubscribe(entry.key_ptr.*);
    }
    
    std.debug.print("🧹 Cleaned up all subscriptions\n");
}

// Example: Error handling
pub fn exampleErrorHandling() !void {
    std.debug.print("=== KuCoin WebSocket Example: Error Handling ===\n");
    
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    try adapter.connect();
    
    // Subscribe to ticker
    try adapter.watchTicker("BTC-USDT", tickerCallback);
    
    // Simulate error handling with invalid symbol
    // (In real app, handle API errors gracefully)
    var invalid_adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer invalid_adapter.deinit();
    
    try invalid_adapter.connect();
    
    // Test with non-existent symbol
    try invalid_adapter.watchTicker("INVALID-PAIR", tickerCallback);
    
    std.debug.print("⚠️  Error handling example completed\n");
}

// Main example runner
pub fn main() !void {
    std.debug.print("🚀 KuCoin WebSocket Adapter Examples\n");
    std.debug.print("==================================\n\n");
    
    // Run examples (uncomment to test)
    try exampleBasicTicker();
    try exampleMarketDataSubscriptions();
    try exampleAuthenticatedTrading();
    try exampleBatchSubscription();
    try exampleFuturesTrading();
    try exampleSandboxTesting();
    try exampleMessageHandling();
    try exampleUnsubscribeOperations();
    try exampleErrorHandling();
    
    std.debug.print("\n✅ All examples completed\n");
}

// Export functions for external usage
pub const KucoinExamples = struct {
    pub const BasicTicker = exampleBasicTicker;
    pub const MarketDataSubscriptions = exampleMarketDataSubscriptions;
    pub const AuthenticatedTrading = exampleAuthenticatedTrading;
    pub const BatchSubscription = exampleBatchSubscription;
    pub const FuturesTrading = exampleFuturesTrading;
    pub const SandboxTesting = exampleSandboxTesting;
    pub const MessageHandling = exampleMessageHandling;
    pub const UnsubscribeOperations = exampleUnsubscribeOperations;
    pub const ErrorHandling = exampleErrorHandling;
};