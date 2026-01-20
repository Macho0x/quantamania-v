// Binance WebSocket Adapter Tests
// Tests for message builders, parsers, and edge cases

const std = @import("std");
const testing = std.testing;

const binance = @import("binance.zig");

// Test helper to create allocator
fn getAllocator() std.mem.Allocator {
    return std.testing.allocator;
}

// === Message Builder Tests ===

test "Binance.buildTickerMessage - spot" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const message = try adapter.buildTickerMessage("BTC/USDT");
    defer getAllocator().free(message);

    try testing.expectEqualStrings("btcusdt@ticker", message);
}

test "Binance.buildTickerMessage - futures" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), true, false);
    defer adapter.deinit();

    const message = try adapter.buildTickerMessage("ETH/USDT");
    defer getAllocator().free(message);

    try testing.expectEqualStrings("ethusdt@ticker", message);
}

test "Binance.buildOHLCVMessage - various timeframes" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const timeframes = &[_][]const u8{ "1m", "5m", "15m", "30m", "1h", "4h", "1d", "1w", "1M" };
    
    inline for (timeframes) |tf| {
        const message = try adapter.buildOHLCVMessage("BTC/USDT", tf);
        defer getAllocator().free(message);
        
        const expected = try std.fmt.allocPrint(getAllocator(), "btcusdt@klines_{s}", .{tf});
        defer getAllocator().free(expected);
        
        try testing.expectEqualStrings(expected, message);
    }
}

test "Binance.buildOrderBookMessage - various depths" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const depths = &[_]u32{ 5, 10, 20, 50, 100, 500, 1000 };
    
    inline for (depths) |depth| {
        const message = try adapter.buildOrderBookMessage("BTC/USDT", depth);
        defer getAllocator().free(message);
        
        try testing.expectEqualStrings(@as([]const u8, "btcusdt@depth10"), message); // Default for invalid depths
    }
    
    const valid_10 = try adapter.buildOrderBookMessage("BTC/USDT", 10);
    defer getAllocator().free(valid_10);
    try testing.expectEqualStrings("btcusdt@depth10", valid_10);
}

test "Binance.buildOrderBookMessage - futures" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), true, false);
    defer adapter.deinit();

    const message = try adapter.buildOrderBookMessage("BTC/USDT", 20);
    defer getAllocator().free(message);

    try testing.expectEqualStrings("btcusdt@depth20@100ms", message);
}

test "Binance.buildTradesMessage" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const message = try adapter.buildTradesMessage("BTC/USDT");
    defer getAllocator().free(message);

    try testing.expectEqualStrings("btcusdt@trade", message);
}

test "Binance.buildAggTradesMessage" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const message = try adapter.buildAggTradesMessage("BTC/USDT");
    defer getAllocator().free(message);

    try testing.expectEqualStrings("btcusdt@aggTrade", message);
}

test "Binance.buildListenKeyPath" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const listen_key = "abc123def456";
    const message = try adapter.buildListenKeyPath(listen_key);
    defer getAllocator().free(message);

    try testing.expectEqualStrings("/abc123def456", message);
}

test "Binance.buildCombinedSubscription" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const streams = &[_][]const u8{ "btcusdt@ticker", "btcusdt@depth10", "btcusdt@trade" };
    const combined = try adapter.buildCombinedSubscription(streams);
    defer getAllocator().free(combined);

    try testing.expectEqualStrings("btcusdt@ticker/btcusdt@depth10/btcusdt@trade", combined);
}

test "Binance.getFullUrl" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const url = try adapter.getFullUrl("/btcusdt@ticker");
    defer getAllocator().free(url);

    try testing.expectEqualStrings("wss://stream.binance.com:9443/ws/btcusdt@ticker", url);
}

test "Binance.getFullUrl - futures" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), true, false);
    defer adapter.deinit();

    const url = try adapter.getFullUrl("/btcusdt@ticker");
    defer getAllocator().free(url);

    try testing.expectEqualStrings("wss://fstream.binance.com/ws/btcusdt@ticker", url);
}

test "Binance.getFullUrl - testnet" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, true);
    defer adapter.deinit();

    const url = try adapter.getFullUrl("/btcusdt@ticker");
    defer getAllocator().free(url);

    try testing.expectEqualStrings("wss://testnet.binance.vision/ws/btcusdt@ticker", url);
}

// === Data Parser Tests ===

test "Binance.parseTickerData" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "24hrTicker",
        \\  "E": 1630000000000,
        \\  "s": "BTCUSDT",
        \\  "c": "45000.50000000",
        \\  "b": "45000.40000000",
        \\  "a": "45000.60000000",
        \\  "v": "1234.56789000",
        \\  "P": "2.35000000",
        \\  "h": "46000.00000000",
        \\  "l": "44000.00000000",
        \\  "q": "55555555.12345678"
        \\}
    ;

    const ticker = try adapter.parseTickerData(json_data);
    defer adapter.cleanupWebSocketTicker(&ticker);

    try testing.expectEqualStrings("BTCUSDT", ticker.symbol);
    try testing.expectEqual(@as(f64, 45000.5), ticker.price);
    try testing.expectEqual(@as(f64, 45000.4), ticker.bid);
    try testing.expectEqual(@as(f64, 45000.6), ticker.ask);
    try testing.expectEqual(@as(f64, 1234.56789), ticker.volume);
    try testing.expectEqual(@as(f64, 2.35), ticker.change_24h);
    try testing.expectEqual(@as(f64, 46000.0), ticker.high_24h);
    try testing.expectEqual(@as(f64, 44000.0), ticker.low_24h);
    try testing.expectEqual(@as(i64, 1630000000000), ticker.event_time);
}

test "Binance.parseOHLCVData" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "kline",
        \\  "E": 1630000000000,
        \\  "s": "BTCUSDT",
        \\  "k": {
        \\    "t": 1630000000000,
        \\    "T": 1630003599999,
        \\    "s": "BTCUSDT",
        \\    "o": "44000.00000000",
        \\    "h": "45000.00000000",
        \\    "l": "43500.00000000",
        \\    "c": "44500.00000000",
        \\    "v": "100.00000000",
        \\    "q": "4440000.00000000",
        \\    "n": 1000,
        \\    "V": "50.00000000",
        \\    "Q": "2220000.00000000"
        \\  }
        \\}
    ;

    const ohlcv = try adapter.parseOHLCVData(json_data);
    defer adapter.cleanupWebSocketOHLCV(&ohlcv);

    try testing.expectEqualStrings("BTCUSDT", ohlcv.symbol);
    try testing.expectEqual(@as(f64, 44000.0), ohlcv.open);
    try testing.expectEqual(@as(f64, 45000.0), ohlcv.high);
    try testing.expectEqual(@as(f64, 43500.0), ohlcv.low);
    try testing.expectEqual(@as(f64, 44500.0), ohlcv.close);
    try testing.expectEqual(@as(f64, 100.0), ohlcv.volume);
    try testing.expectEqual(@as(i64, 1630003599999), ohlcv.close_time);
    try testing.expectEqual(@as(f64, 4440000.0), ohlcv.quote_asset_volume);
    try testing.expectEqual(@as(u64, 1000), ohlcv.number_of_trades);
    try testing.expectEqual(@as(f64, 50.0), ohlcv.taker_buy_base_volume);
    try testing.expectEqual(@as(f64, 2220000.0), ohlcv.taker_buy_quote_volume);
}

test "Binance.parseOrderBookData" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "lastUpdateId": 160,
        \\  "bids": [
        \\    ["45000.00", "0.5", []],
        \\    ["44999.00", "1.0", []],
        \\    ["44998.00", "2.0", []]
        \\  ],
        \\  "asks": [
        \\    ["45001.00", "0.3", []],
        \\    ["45002.00", "0.8", []],
        \\    ["45003.00", "1.5", []]
        \\  ]
        \\}
    ;

    const ob = try adapter.parseOrderBookData(json_data);
    defer adapter.cleanupWebSocketOrderBook(&ob);

    try testing.expectEqual(@as(i64, 160), ob.last_update_id);
    try testing.expectEqual(@as(usize, 3), ob.bids.len);
    try testing.expectEqual(@as(usize, 3), ob.asks.len);

    // Check first bid
    try testing.expectEqual(@as(f64, 45000.0), ob.bids[0].price);
    try testing.expectEqual(@as(f64, 0.5), ob.bids[0].amount);

    // Check first ask
    try testing.expectEqual(@as(f64, 45001.0), ob.asks[0].price);
    try testing.expectEqual(@as(f64, 0.3), ob.asks[0].amount);
}

test "Binance.parseOrderBookData - with event fields" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), true, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "depthUpdate",
        \\  "E": 1630000000000,
        \\  "s": "BTCUSDT",
        \\  "U": 150,
        \\  "u": 160,
        \\  "b": [
        \\    ["45000.00", "0.5", []]
        \\  ],
        \\  "a": [
        \\    ["45001.00", "0.3", []]
        \\  ]
        \\}
    ;

    const ob = try adapter.parseOrderBookData(json_data);
    defer adapter.cleanupWebSocketOrderBook(&ob);

    try testing.expectEqual(@as(i64, 1630000000000), ob.event_time);
    try testing.expectEqual(@as(i64, 150), ob.first_update_id);
    try testing.expectEqual(@as(i64, 160), ob.last_update_id);
}

test "Binance.parseTradeData" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "trade",
        \\  "E": 1630000000000,
        \\  "s": "BTCUSDT",
        \\  "t": 123456789,
        \\  "p": "45000.50000000",
        \\  "q": "0.10000000",
        \\  "b": 987654321,
        \\  "a": 123456788,
        \\  "T": 1630000000000,
        \\  "m": true
        \\}
    ;

    const trade = try adapter.parseTradeData(json_data);
    defer adapter.cleanupWebSocketTrade(&trade);

    try testing.expectEqualStrings("trade", trade.event_type);
    try testing.expectEqual(@as(i64, 1630000000000), trade.event_time);
    try testing.expectEqualStrings("BTCUSDT", trade.symbol);
    try testing.expectEqual(@as(i64, 123456789), trade.trade_id);
    try testing.expectEqual(@as(f64, 45000.5), trade.price);
    try testing.expectEqual(@as(f64, 0.1), trade.quantity);
    try testing.expectEqual(@as(i64, 987654321), trade.buyer_order_id);
    try testing.expectEqual(@as(i64, 123456788), trade.seller_order_id);
    try testing.expectEqual(@as(i64, 1630000000000), trade.trade_time);
    try testing.expect(trade.is_buyer_maker);
}

test "Binance.parseAggTradeData" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "aggTrade",
        \\  "E": 1630000000000,
        \\  "s": "BTCUSDT",
        \\  "a": 123456789,
        \\  "p": "45000.50000000",
        \\  "q": "1.50000000",
        \\  "f": 111111,
        \\  "l": 222222,
        \\  "T": 1630000000000,
        \\  "m": false
        \\}
    ;

    const trade = try adapter.parseAggTradeData(json_data);
    defer adapter.cleanupWebSocketTrade(&trade);

    try testing.expectEqualStrings("aggTrade", trade.event_type);
    try testing.expectEqual(@as(i64, 123456789), trade.trade_id);
    try testing.expectEqual(@as(f64, 45000.5), trade.price);
    try testing.expectEqual(@as(f64, 1.5), trade.quantity);
    try testing.expect(!trade.is_buyer_maker);
}

test "Binance.parseBalanceData" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "outboundAccountPosition",
        \\  "E": 1630000000000,
        \\  "u": 1630000000000,
        \\  "B": [
        \\    {"a": "BTC", "f": "1.50000000", "l": "0.50000000"},
        \\    {"a": "USDT", "f": "10000.00000000", "l": "0.00000000"},
        \\    {"a": "ETH", "f": "10.00000000", "l": "2.00000000"}
        \\  ]
        \\}
    ;

    const balance = try adapter.parseBalanceData(json_data);
    defer adapter.cleanupWebSocketBalance(&balance);

    try testing.expectEqualStrings("outboundAccountPosition", balance.event_type);
    try testing.expectEqual(@as(i64, 1630000000000), balance.event_time);
    try testing.expectEqual(@as(i64, 1630000000000), balance.last_account_update);
    try testing.expectEqual(@as(usize, 3), balance.balances.len);

    // Check first balance
    try testing.expectEqualStrings("BTC", balance.balances[0].asset);
    try testing.expectEqual(@as(f64, 1.5), balance.balances[0].free);
    try testing.expectEqual(@as(f64, 0.5), balance.balances[0].locked);

    // Check second balance
    try testing.expectEqualStrings("USDT", balance.balances[1].asset);
    try testing.expectEqual(@as(f64, 10000.0), balance.balances[1].free);
    try testing.expectEqual(@as(f64, 0.0), balance.balances[1].locked);
}

test "Binance.parseOrderData" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "executionReport",
        \\  "E": 1630000000000,
        \\  "s": "BTCUSDT",
        \\  "c": "myOrder123",
        \\  "S": "BUY",
        \\  "o": "LIMIT",
        \\  "f": "GTC",
        \\  "q": "1.00000000",
        \\  "p": "45000.00000000",
        \\  "P": "0.00000000",
        \\  "F": "0.00000000",
        \\  "C": "",
        \\  "x": "NEW",
        \\  "X": "NEW",
        \\  "r": "NONE",
        \\  "i": 123456789,
        \\  "l": "0.00000000",
        \\  "z": "0.00000000",
        \\  "L": "0.00000000",
        \\  "n": "0.00000000",
        \\  "N": null,
        \\  "T": 1630000000000,
        \\  "t": -1,
        \\  "O": 1629999000000,
        \\  "m": false,
        \\  "M": false,
        \\  "g": -1,
        \\  "Z": "0.00000000",
        \\  "Y": "0.00000000",
        \\  "Q": "0.00000000"
        \\}
    ;

    const order = try adapter.parseOrderData(json_data);
    defer adapter.cleanupWebSocketOrder(&order);

    try testing.expectEqualStrings("executionReport", order.event_type);
    try testing.expectEqual(@as(i64, 1630000000000), order.event_time);
    try testing.expectEqualStrings("BTCUSDT", order.symbol);
    try testing.expectEqualStrings("myOrder123", order.client_order_id);
    try testing.expectEqual(binance.OrderSide.buy, order.side);
    try testing.expectEqual(binance.OrderType.limit, order.order_type);
    try testing.expectEqual(binance.OrderStatus.open, order.order_status);
    try testing.expectEqual(@as(i64, 123456789), order.order_id);
    try testing.expectEqual(@as(i64, -1), order.order_list_id);
    try testing.expectEqual(@as(f64, 45000.0), order.price);
    try testing.expectEqual(@as(f64, 1.0), order.original_quantity);
    try testing.expectEqual(@as(f64, 0.0), order.executed_quantity);
}

test "Binance.parseOrderData - filled order" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "executionReport",
        \\  "E": 1630000000000,
        \\  "s": "BTCUSDT",
        \\  "c": "myOrder123",
        \\  "S": "SELL",
        \\  "o": "MARKET",
        \\  "f": "IOC",
        \\  "q": "1.00000000",
        \\  "p": "0.00000000",
        \\  "P": "0.00000000",
        \\  "F": "1.00000000",
        \\  "C": "",
        \\  "x": "TRADE",
        \\  "X": "FILLED",
        \\  "r": "NONE",
        \\  "i": 123456789,
        \\  "l": "1.00000000",
        \\  "z": "1.00000000",
        \\  "L": "44999.50000000",
        \\  "n": "44.99950000",
        \\  "N": "USDT",
        \\  "T": 1630000000000,
        \\  "t": 987654321,
        \\  "O": 1629999000000,
        \\  "m": false,
        \\  "M": true,
        \\  "g": -1,
        \\  "Z": "44999.50000000",
        \\  "Y": "44999.50000000",
        \\  "Q": "0.00000000"
        \\}
    ;

    const order = try adapter.parseOrderData(json_data);
    defer adapter.cleanupWebSocketOrder(&order);

    try testing.expectEqual(binance.OrderSide.sell, order.side);
    try testing.expectEqual(binance.OrderType.market, order.order_type);
    try testing.expectEqual(binance.OrderStatus.closed, order.order_status);
    try testing.expectEqual(@as(f64, 1.0), order.executed_quantity);
    try testing.expect(order.commission != null);
    if (order.commission) |comm| {
        try testing.expectEqual(@as(f64, 44.9995), comm);
    }
    try testing.expect(order.commission_asset != null);
    if (order.commission_asset) |asset| {
        try testing.expectEqualStrings("USDT", asset);
    }
}

// === Edge Cases Tests ===

test "Binance.parseTickerData - null fields handling" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "24hrTicker",
        \\  "E": 1630000000000,
        \\  "s": "BTCUSDT",
        \\  "c": "45000.50000000",
        \\  "b": "45000.40000000",
        \\  "a": "45000.60000000",
        \\  "v": "0.00000000",
        \\  "P": "0.00000000",
        \\  "h": "45000.50000000",
        \\  "l": "45000.50000000",
        \\  "q": "0.00000000"
        \\}
    ;

    const ticker = try adapter.parseTickerData(json_data);
    defer adapter.cleanupWebSocketTicker(&ticker);

    try testing.expectEqual(@as(f64, 0.0), ticker.volume);
    try testing.expectEqual(@as(f64, 0.0), ticker.change_24h);
}

test "Binance.parseOrderBookData - empty arrays" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "lastUpdateId": 160,
        \\  "bids": [],
        \\  "asks": []
        \\}
    ;

    const ob = try adapter.parseOrderBookData(json_data);
    defer adapter.cleanupWebSocketOrderBook(&ob);

    try testing.expectEqual(@as(usize, 0), ob.bids.len);
    try testing.expectEqual(@as(usize, 0), ob.asks.len);
}

test "Binance.parseBalanceData - empty balances" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "outboundAccountPosition",
        \\  "E": 1630000000000,
        \\  "u": 1630000000000,
        \\  "B": []
        \\}
    ;

    const balance = try adapter.parseBalanceData(json_data);
    defer adapter.cleanupWebSocketBalance(&balance);

    try testing.expectEqual(@as(usize, 0), balance.balances.len);
}

test "Binance.normalizeSymbol - various formats" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const test_cases = &[_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = "BTC/USDT", .expected = "btcusdt" },
        .{ .input = "ETH/USDT", .expected = "ethusdt" },
        .{ .input = "SOL/USDT", .expected = "solusdt" },
        .{ .input = "btc/usdt", .expected = "btcusdt" },
    };

    for (test_cases) |case| {
        const result = try adapter.normalizeSymbol(getAllocator(), case.input);
        defer getAllocator().free(result);
        try testing.expectEqualStrings(case.expected, result);
    }
}

test "Binance.buildCombinedSubscription - single stream" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const streams = &[_][]const u8{"btcusdt@ticker"};
    const combined = try adapter.buildCombinedSubscription(streams);
    defer getAllocator().free(combined);

    try testing.expectEqualStrings("btcusdt@ticker", combined);
}

test "Binance.buildCombinedSubscription - empty streams error" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const streams = &[_][]const u8{};
    const result = adapter.buildCombinedSubscription(streams);

    try testing.expectError(error.EmptyStreams, result);
}

// === Performance Tests ===

test "Binance performance - parse 1000 ticker messages" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "24hrTicker",
        \\  "E": 1630000000000,
        \\  "s": "BTCUSDT",
        \\  "c": "45000.50000000",
        \\  "b": "45000.40000000",
        \\  "a": "45000.60000000",
        \\  "v": "1234.56789000",
        \\  "P": "2.35000000",
        \\  "h": "46000.00000000",
        \\  "l": "44000.00000000",
        \\  "q": "55555555.12345678"
        \\}
    ;

    var i: usize = 0;
    const start_time = std.time.nanoTimestamp();
    while (i < 1000) : (i += 1) {
        const ticker = try adapter.parseTickerData(json_data);
        adapter.cleanupWebSocketTicker(&ticker);
    }
    const end_time = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

    // Should parse 1000 messages in less than 100ms (less than 0.1ms per message)
    try testing.expect(elapsed_ms < 100.0);
}

test "Binance performance - parse 1000 trade messages" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "trade",
        \\  "E": 1630000000000,
        \\  "s": "BTCUSDT",
        \\  "t": 123456789,
        \\  "p": "45000.50000000",
        \\  "q": "0.10000000",
        \\  "b": 987654321,
        \\  "a": 123456788,
        \\  "T": 1630000000000,
        \\  "m": true
        \\}
    ;

    var i: usize = 0;
    const start_time = std.time.nanoTimestamp();
    while (i < 1000) : (i += 1) {
        const trade = try adapter.parseTradeData(json_data);
        adapter.cleanupWebSocketTrade(&trade);
    }
    const end_time = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

    // Should parse 1000 messages in less than 100ms (less than 0.1ms per message)
    try testing.expect(elapsed_ms < 100.0);
}

test "Binance performance - message building" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    var i: usize = 0;
    const start_time = std.time.nanoTimestamp();
    while (i < 1000) : (i += 1) {
        const message = try adapter.buildTickerMessage("BTC/USDT");
        getAllocator().free(message);
    }
    const end_time = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

    // Should build 1000 messages in less than 50ms (less than 0.05ms per message)
    try testing.expect(elapsed_ms < 50.0);
}

// === Memory Leak Tests ===

test "Binance memory - parse and cleanup ticker" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "24hrTicker",
        \\  "E": 1630000000000,
        \\  "s": "BTCUSDT",
        \\  "c": "45000.50000000",
        \\  "b": "45000.40000000",
        \\  "a": "45000.60000000",
        \\  "v": "1234.56789000",
        \\  "P": "2.35000000",
        \\  "h": "46000.00000000",
        \\  "l": "44000.00000000",
        \\  "q": "55555555.12345678"
        \\}
    ;

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const ticker = try adapter.parseTickerData(json_data);
        adapter.cleanupWebSocketTicker(&ticker);
    }

    // If we get here without crashing, memory cleanup is working
    try testing.expect(true);
}

test "Binance memory - parse and cleanup orderbook" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "lastUpdateId": 160,
        \\  "bids": [
        \\    ["45000.00", "0.5", []],
        \\    ["44999.00", "1.0", []]
        \\  ],
        \\  "asks": [
        \\    ["45001.00", "0.3", []],
        \\    ["45002.00", "0.8", []]
        \\  ]
        \\}
    ;

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const ob = try adapter.parseOrderBookData(json_data);
        adapter.cleanupWebSocketOrderBook(&ob);
    }

    // If we get here without crashing, memory cleanup is working
    try testing.expect(true);
}

test "Binance memory - parse and cleanup balance" {
    var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
    defer adapter.deinit();

    const json_data = 
        \\{
        \\  "e": "outboundAccountPosition",
        \\  "E": 1630000000000,
        \\  "u": 1630000000000,
        \\  "B": [
        \\    {"a": "BTC", "f": "1.50000000", "l": "0.50000000"},
        \\    {"a": "USDT", "f": "10000.00000000", "l": "0.00000000"}
        \\  ]
        \\}
    ;

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const balance = try adapter.parseBalanceData(json_data);
        adapter.cleanupWebSocketBalance(&balance);
    }

    // If we get here without crashing, memory cleanup is working
    try testing.expect(true);
}

// === Integration Tests (with error handling for network) ===

test "Binance - adapter initialization" {
    // Test spot
    {
        var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, false);
        defer adapter.deinit();
        try testing.expect(!adapter.is_futures);
        try testing.expectEqualStrings("wss://stream.binance.com:9443/ws", adapter.base_url);
    }

    // Test futures
    {
        var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), true, false);
        defer adapter.deinit();
        try testing.expect(adapter.is_futures);
        try testing.expectEqualStrings("wss://fstream.binance.com/ws", adapter.base_url);
    }

    // Test testnet
    {
        var adapter = try binance.BinanceWebSocketAdapter.init(getAllocator(), false, true);
        defer adapter.deinit();
        try testing.expect(!adapter.is_futures);
        try testing.expectEqualStrings("wss://testnet.binance.vision/ws", adapter.base_url);
    }
}

// Run all tests with: zig test src/websocket/adapters/binance_test.zig
