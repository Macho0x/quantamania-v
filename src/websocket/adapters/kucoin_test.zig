const std = @import("std");
const testing = std.testing;
const allocator = std.heap.page_allocator;

// Import the adapter and dependencies
const kucoin_adapter = @import("kucoin.zig");
const KucoinWebSocketAdapter = kucoin_adapter.KucoinWebSocketAdapter;
const types = @import("../../types.zig");
const json = @import("../../utils/json.zig");

test "KucoinWebSocketAdapter initialization" {
    const testnet = false;
    const adapter = try KucoinWebSocketAdapter.init(allocator, testnet);
    defer adapter.deinit();
    
    try testing.expect(adapter.isConnected() == false);
    try testing.expect(adapter.auth_token == null);
    try testing.expectEqual(@as(usize, 0), adapter.subscriptions.count());
    try testing.expectEqual(@as(i64, 0), adapter.token_expires_at);
}

test "KucoinWebSocketAdapter testnet initialization" {
    const testnet = true;
    const adapter = try KucoinWebSocketAdapter.init(allocator, testnet);
    defer adapter.deinit();
    
    try testing.expect(adapter.testnet == true);
}

test "Authentication token generation" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const api_key = "test_api_key";
    const api_secret = "test_api_secret";
    const passphrase = "test_passphrase";
    
    try adapter.authenticate(api_key, api_secret, passphrase);
    
    try testing.expect(adapter.auth_token != null);
    try testing.expect(adapter.token_expires_at > 0);
}

test "Ticker subscription creation" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const symbol = "BTC-USDT";
    var callback_called = false;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_called = true;
        }
    }.test_callback;
    
    try adapter.watchTicker(symbol, callback);
    
    try testing.expectEqual(@as(usize, 1), adapter.subscriptions.count());
    
    // Verify subscription was stored
    const sub_id = try std.fmt.allocPrint(allocator, "ticker_{s}", .{symbol});
    defer allocator.free(sub_id);
    
    try testing.expect(adapter.subscriptions.get(sub_id) != null);
}

test "OrderBook subscription with different levels" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const symbol = "BTC-USDT";
    var callback_called = false;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_called = true;
        }
    }.test_callback;
    
    // Test 20 level subscription
    try adapter.watchOrderBook(symbol, 20, callback);
    
    try testing.expectEqual(@as(usize, 1), adapter.subscriptions.count());
    
    // Test 100 level subscription
    try adapter.watchOrderBook(symbol, 100, callback);
    
    try testing.expectEqual(@as(usize, 2), adapter.subscriptions.count());
}

test "Trades subscription" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const symbol = "BTC-USDT";
    var callback_called = false;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_called = true;
        }
    }.test_callback;
    
    try adapter.watchTrades(symbol, callback);
    
    try testing.expectEqual(@as(usize, 1), adapter.subscriptions.count());
}

test "OHLCV subscription with different timeframes" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const symbol = "BTC-USDT";
    const timeframes = &[_][]const u8{ "1min", "5min", "1hour", "1day" };
    var callback_count: usize = 0;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
        }
    }.test_callback;
    
    for (timeframes) |tf| {
        try adapter.watchOHLCV(symbol, tf, callback);
    }
    
    try testing.expectEqual(@as(usize, 4), adapter.subscriptions.count());
}

test "Balance subscription requires authentication" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    var callback_called = false;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_called = true;
        }
    }.test_callback;
    
    // Should fail without authentication
    try testing.expectError(error.AuthenticationRequired, adapter.watchBalance(callback));
}

test "Balance subscription after authentication" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    // First authenticate
    try adapter.authenticate("test_api_key", "test_api_secret", "test_passphrase");
    
    var callback_called = false;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_called = true;
        }
    }.test_callback;
    
    // Should work after authentication
    try adapter.watchBalance(callback);
    
    try testing.expectEqual(@as(usize, 1), adapter.subscriptions.count());
}

test "Orders subscription requires authentication" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const symbol = "BTC-USDT";
    var callback_called = false;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_called = true;
        }
    }.test_callback;
    
    // Should fail without authentication
    try testing.expectError(error.AuthenticationRequired, adapter.watchOrders(symbol, callback));
}

test "Orders subscription after authentication" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    // First authenticate
    try adapter.authenticate("test_api_key", "test_api_secret", "test_passphrase");
    
    const symbol = "BTC-USDT";
    var callback_called = false;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_called = true;
        }
    }.test_callback;
    
    // Should work after authentication
    try adapter.watchOrders(symbol, callback);
    
    try testing.expectEqual(@as(usize, 1), adapter.subscriptions.count());
}

test "Ticker message parsing" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const symbol = "BTC-USDT";
    var callback_data: ?[]const u8 = null;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            callback_data = data;
        }
    }.test_callback;
    
    try adapter.watchTicker(symbol, callback);
    
    // Simulate ticker message
    const ticker_message = 
        \\{
        \\"type": "message",
        \\"topic": "/market/ticker:BTC-USDT",
        \\"subject": "trade.ticker",
        \\"data": {
            \\"sequence": 1234567,
            \\"price": "45234.56",
            \\"size": "0.01",
            \\"bestAsk": "45235.12",
            \\"bestAskSize": "1.5",
            \\"bestBid": "45233.00",
            \\"bestBidSize": "2.0",
            \\"time": 1577836800000
        \\}
        \\}
    ;
    
    try adapter.handleMessage(ticker_message);
    
    try testing.expect(callback_data != null);
    if (callback_data) |data| {
        // Verify callback was called with parsed data
        try testing.expect(std.mem.indexOf(u8, data, symbol) != null);
        try testing.expect(std.mem.indexOf(u8, data, "45234.56") != null);
    }
}

test "OrderBook message parsing" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const symbol = "BTC-USDT";
    var callback_data: ?[]const u8 = null;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            callback_data = data;
        }
    }.test_callback;
    
    try adapter.watchOrderBook(symbol, 20, callback);
    
    // Simulate orderbook message
    const orderbook_message = 
        \\{
        \\"type": "message",
        \\"topic": "/market/level2:BTC-USDT",
        \\"subject": "trade.l2snapshot",
        \\"data": {
            \\"symbol": "BTC-USDT",
            \\"bids": [["45233.00", "2.0"], ["45232.00", "1.5"]],
            \\"asks": [["45235.12", "1.5"], ["45236.00", "2.0"]],
            \\"time": 1577836800000
        \\}
        \\}
    ;
    
    try adapter.handleMessage(orderbook_message);
    
    try testing.expect(callback_data != null);
    if (callback_data) |data| {
        // Verify callback was called with parsed data
        try testing.expect(std.mem.indexOf(u8, data, symbol) != null);
        try testing.expect(std.mem.indexOf(u8, data, "bids") != null);
        try testing.expect(std.mem.indexOf(u8, data, "asks") != null);
    }
}

test "Ping/Pong handling" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const ping_message = 
        \\{
        \\"ping": 1577836800000
        \\}
    ;
    
    // Should handle ping without error
    try adapter.handleMessage(ping_message);
    
    // Test pong response
    const pong_message = 
        \\{
        \\"type": "pong",
        \\"data": 1577836800000
        \\}
    ;
    
    try adapter.handleMessage(pong_message);
}

test "Error message handling" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const error_message = 
        \\{
        \\"type": "error",
        \\"code": "401",
        \\"msg": "Unauthorized access"
        \\}
    ;
    
    // Should handle error without crashing
    try adapter.handleMessage(error_message);
}

test "Batch subscription" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    var ticker_callback_count: usize = 0;
    var orderbook_callback_count: usize = 0;
    
    const ticker_callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            ticker_callback_count += 1;
        }
    }.test_callback;
    
    const orderbook_callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            orderbook_callback_count += 1;
        }
    }.test_callback;
    
    const batch_requests = &[_]KucoinWebSocketAdapter.BatchSubscriptionRequest{
        .{ 
            .subscription_type = .ticker, 
            .symbol = "BTC-USDT", 
            .timeframe = null, 
            .limit = null, 
            .callback = ticker_callback 
        },
        .{ 
            .subscription_type = .orderbook, 
            .symbol = "ETH-USDT", 
            .timeframe = null, 
            .limit = 20, 
            .callback = orderbook_callback 
        },
        .{ 
            .subscription_type = .trades, 
            .symbol = "ADA-USDT", 
            .timeframe = null, 
            .limit = null, 
            .callback = ticker_callback 
        },
    };
    
    try adapter.batchSubscribe(batch_requests);
    
    try testing.expectEqual(@as(usize, 3), adapter.subscriptions.count());
}

test "Unsubscribe functionality" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const symbol = "BTC-USDT";
    var callback_called = false;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_called = true;
        }
    }.test_callback;
    
    try adapter.watchTicker(symbol, callback);
    try testing.expectEqual(@as(usize, 1), adapter.subscriptions.count());
    
    const sub_id = try std.fmt.allocPrint(allocator, "ticker_{s}", .{symbol});
    defer allocator.free(sub_id);
    
    try adapter.unsubscribe(sub_id);
    try testing.expectEqual(@as(usize, 0), adapter.subscriptions.count());
}

test "Unsubscribe non-existent subscription" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    // Should handle non-existent subscription gracefully
    try adapter.unsubscribe("non_existent_sub");
    try testing.expectEqual(@as(usize, 0), adapter.subscriptions.count());
}

test "Message parsing performance" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const symbol = "BTC-USDT";
    var callback_called = false;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_called = true;
        }
    }.test_callback;
    
    try adapter.watchTicker(symbol, callback);
    
    const ticker_message = 
        \\{
        \\"type": "message",
        \\"topic": "/market/ticker:BTC-USDT",
        \\"subject": "trade.ticker",
        \\"data": {
            \\"sequence": 1234567,
            \\"price": "45234.56",
            \\"size": "0.01",
            \\"bestAsk": "45235.12",
            \\"bestAskSize": "1.5",
            \\"bestBid": "45233.00",
            \\"bestBidSize": "2.0",
            \\"time": 1577836800000
        \\}
        \\}
    ;
    
    const start_time = std.time.nanoTimestamp();
    
    // Parse 1000 messages to test performance
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        try adapter.handleMessage(ticker_message);
    }
    
    const end_time = std.time.nanoTimestamp();
    const total_time = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000; // Convert to milliseconds
    
    // Should parse messages in under 5ms (target <5ms per message)
    const avg_time_per_message = total_time / 1000.0;
    try testing.expect(avg_time_per_message < 5.0);
}

test "Memory leak prevention" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const symbol = "BTC-USDT";
    var callback_called = false;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_called = true;
        }
    }.test_callback;
    
    // Subscribe and unsubscribe multiple times
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try adapter.watchTicker(symbol, callback);
        
        const sub_id = try std.fmt.allocPrint(allocator, "ticker_{s}", .{symbol});
        defer allocator.free(sub_id);
        
        try adapter.unsubscribe(sub_id);
    }
    
    try testing.expectEqual(@as(usize, 0), adapter.subscriptions.count());
}

test "Multiple symbols subscription" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    const symbols = &[_][]const u8{ "BTC-USDT", "ETH-USDT", "ADA-USDT", "DOT-USDT", "LINK-USDT" };
    var callback_count: usize = 0;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_count += 1;
        }
    }.test_callback;
    
    for (symbols) |symbol| {
        try adapter.watchTicker(symbol, callback);
    }
    
    try testing.expectEqual(@as(usize, symbols.len), adapter.subscriptions.count());
    
    // Test message routing for each symbol
    for (symbols) |symbol| {
        const ticker_message = try std.fmt.allocPrint(allocator,
            \\{{
            \\"type": "message",
            \\"topic": "/market/ticker:{s}",
            \\"subject": "trade.ticker",
            \\"data": {{
                \\"sequence": 1234567,
                \\"price": "45234.56",
                \\"size": "0.01",
                \\"time": 1577836800000
            \\}}
            \\}}
        , .{symbol});
        defer allocator.free(ticker_message);
        
        callback_count = 0;
        try adapter.handleMessage(ticker_message);
        try testing.expectEqual(@as(usize, 1), callback_count);
    }
}

test "Future vs Spot symbol handling" {
    const adapter = try KucoinWebSocketAdapter.init(allocator, false);
    defer adapter.deinit();
    
    // Test both spot and futures symbols
    const symbols = &[_][]const u8{ 
        "BTC-USDT",      // Spot
        "BTCUSDT",       // Alternative spot format
        "BTC-USD-SWAP",  // Futures/Swap
    };
    
    var callback_count: usize = 0;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            _ = data;
            callback_count += 1;
        }
    }.test_callback;
    
    for (symbols) |symbol| {
        try adapter.watchTicker(symbol, callback);
    }
    
    try testing.expectEqual(@as(usize, symbols.len), adapter.subscriptions.count());
}

// Integration test with KuCoin sandbox
test "KuCoin sandbox integration test" {
    if (!testing.allocator.allocTest()) return error.SkipZigTest;
    
    const sandbox_adapter = try KucoinWebSocketAdapter.init(allocator, true);
    defer sandbox_adapter.deinit();
    
    // Test connection to sandbox environment
    try testing.expect(sandbox_adapter.testnet == true);
    
    // Test ticker subscription in sandbox
    const symbol = "BTC-USDT";
    var received_data = false;
    
    const callback = struct {
        fn test_callback(data: []const u8) void {
            if (std.mem.indexOf(u8, data, "price") != null) {
                received_data = true;
            }
        }
    }.test_callback;
    
    try sandbox_adapter.watchTicker(symbol, callback);
    try testing.expectEqual(@as(usize, 1), sandbox_adapter.subscriptions.count());
}