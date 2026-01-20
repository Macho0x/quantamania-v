// Binance WebSocket Adapter Examples
// Demonstrates real-time market data and account updates

const std = @import("std");
const binance_ws = @import("src/websocket/adapters/binance.zig").BinanceWebSocketAdapter;
const ws = @import("src/websocket/ws.zig").WebSocketClient;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Binance WebSocket Adapter Examples ===\n\n", .{});

    // Example 1: Create adapter for Spot market
    try exampleCreateSpotAdapter(allocator);

    // Example 2: Create adapter for Futures market
    try exampleCreateFuturesAdapter(allocator);

    // Example 3: Create adapter for Testnet
    try exampleCreateTestnetAdapter(allocator);

    // Example 4: Build subscription messages for market data
    try exampleBuildMarketDataSubscriptions(allocator);

    // Example 5: Parse ticker data
    try exampleParseTickerData(allocator);

    // Example 6: Parse OHLCV data
    try exampleParseOHLCVData(allocator);

    // Example 7: Parse order book data
    try exampleParseOrderBookData(allocator);

    // Example 8: Parse trade data
    try exampleParseTradeData(allocator);

    // Example 9: Parse balance data
    try exampleParseBalanceData(allocator);

    // Example 10: Parse order data
    try exampleParseOrderData(allocator);

    // Example 11: Build combined subscription
    try exampleCombinedSubscription(allocator);

    std.debug.print("\n=== All examples completed successfully! ===\n", .{});
}

// Example 1: Create adapter for Spot market
fn exampleCreateSpotAdapter(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 1: Create Spot market adapter\n", .{});
    
    var adapter = try binance_ws.init(allocator, false, false);
    defer adapter.deinit();
    
    std.debug.print("  ✓ Spot adapter created\n", .{});
    std.debug.print("  Base URL: {s}\n", .{adapter.base_url});
    std.debug.print("  Is futures: {}\n", .{adapter.is_futures});
    std.debug.print("\n", .{});
}

// Example 2: Create adapter for Futures market
fn exampleCreateFuturesAdapter(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 2: Create Futures market adapter\n", .{});
    
    var adapter = try binance_ws.init(allocator, true, false);
    defer adapter.deinit();
    
    std.debug.print("  ✓ Futures adapter created\n", .{});
    std.debug.print("  Base URL: {s}\n", .{adapter.base_url});
    std.debug.print("  Is futures: {}\n", .{adapter.is_futures});
    std.debug.print("\n", .{});
}

// Example 3: Create adapter for Testnet
fn exampleCreateTestnetAdapter(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 3: Create Testnet adapter\n", .{});
    
    var adapter = try binance_ws.init(allocator, false, true);
    defer adapter.deinit();
    
    std.debug.print("  ✓ Testnet adapter created\n", .{});
    std.debug.print("  Base URL: {s}\n", .{adapter.base_url});
    std.debug.print("\n", .{});
}

// Example 4: Build subscription messages for market data
fn exampleBuildMarketDataSubscriptions(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 4: Build market data subscription messages\n", .{});
    
    var adapter = try binance_ws.init(allocator, false, false);
    defer adapter.deinit();
    
    // Ticker subscription
    const ticker_msg = try adapter.buildTickerMessage("BTC/USDT");
    defer allocator.free(ticker_msg);
    std.debug.print("  Ticker stream: {s}\n", .{ticker_msg});
    
    // OHLCV subscription (1 hour candles)
    const ohlcv_msg = try adapter.buildOHLCVMessage("BTC/USDT", "1h");
    defer allocator.free(ohlcv_msg);
    std.debug.print("  OHLCV stream: {s}\n", .{ohlcv_msg});
    
    // Order book subscription (10 levels)
    const ob_msg = try adapter.buildOrderBookMessage("BTC/USDT", 10);
    defer allocator.free(ob_msg);
    std.debug.print("  Order book stream: {s}\n", .{ob_msg});
    
    // Trades subscription
    const trades_msg = try adapter.buildTradesMessage("BTC/USDT");
    defer allocator.free(trades_msg);
    std.debug.print("  Trades stream: {s}\n", .{trades_msg});
    
    std.debug.print("  ✓ All subscription messages built\n", .{});
    std.debug.print("\n", .{});
}

// Example 5: Parse ticker data
fn exampleParseTickerData(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 5: Parse ticker data\n", .{});
    
    var adapter = try binance_ws.init(allocator, false, false);
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
    
    std.debug.print("  Symbol: {s}\n", .{ticker.symbol});
    std.debug.print("  Price: ${d:.2}\n", .{ticker.price});
    std.debug.print("  Bid: ${d:.2}\n", .{ticker.bid});
    std.debug.print("  Ask: ${d:.2}\n", .{ticker.ask});
    std.debug.print("  Volume: {d:.4} BTC\n", .{ticker.volume});
    std.debug.print("  24h Change: {d:.2}%\n", .{ticker.change_24h});
    std.debug.print("  High: ${d:.2}\n", .{ticker.high_24h});
    std.debug.print("  Low: ${d:.2}\n", .{ticker.low_24h});
    std.debug.print("  ✓ Ticker parsed\n", .{});
    std.debug.print("\n", .{});
}

// Example 6: Parse OHLCV data
fn exampleParseOHLCVData(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 6: Parse OHLCV data\n", .{});
    
    var adapter = try binance_ws.init(allocator, false, false);
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
    
    std.debug.print("  Symbol: {s}\n", .{ohlcv.symbol});
    std.debug.print("  Open: ${d:.2}\n", .{ohlcv.open});
    std.debug.print("  High: ${d:.2}\n", .{ohlcv.high});
    std.debug.print("  Low: ${d:.2}\n", .{ohlcv.low});
    std.debug.print("  Close: ${d:.2}\n", .{ohlcv.close});
    std.debug.print("  Volume: {d:.4} BTC\n", .{ohlcv.volume});
    std.debug.print("  Quote Volume: ${d:.2} USDT\n", .{ohlcv.quote_asset_volume});
    std.debug.print("  Trades: {d}\n", .{ohlcv.number_of_trades});
    std.debug.print("  ✓ OHLCV parsed\n", .{});
    std.debug.print("\n", .{});
}

// Example 7: Parse order book data
fn exampleParseOrderBookData(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 7: Parse order book data\n", .{});
    
    var adapter = try binance_ws.init(allocator, false, false);
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
    
    std.debug.print("  Symbol: {s}\n", .{ob.symbol});
    std.debug.print("  Update ID: {d}\n", .{ob.last_update_id});
    std.debug.print("  Bids ({d} levels):\n", .{ob.bids.len});
    for (ob.bids[0..@min(3, ob.bids.len)]) |bid| {
        std.debug.print("    ${d:.2} ({d:.4} BTC)\n", .{bid.price, bid.amount});
    }
    std.debug.print("  Asks ({d} levels):\n", .{ob.asks.len});
    for (ob.asks[0..@min(3, ob.asks.len)]) |ask| {
        std.debug.print("    ${d:.2} ({d:.4} BTC)\n", .{ask.price, ask.amount});
    }
    std.debug.print("  ✓ Order book parsed\n", .{});
    std.debug.print("\n", .{});
}

// Example 8: Parse trade data
fn exampleParseTradeData(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 8: Parse trade data\n", .{});
    
    var adapter = try binance_ws.init(allocator, false, false);
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
    
    std.debug.print("  Event: {s}\n", .{trade.event_type});
    std.debug.print("  Symbol: {s}\n", .{trade.symbol});
    std.debug.print("  Trade ID: {d}\n", .{trade.trade_id});
    std.debug.print("  Price: ${d:.2}\n", .{trade.price});
    std.debug.print("  Quantity: {d:.4} BTC\n", .{trade.quantity});
    std.debug.print("  Buyer Maker: {}\n", .{trade.is_buyer_maker});
    std.debug.print("  ✓ Trade parsed\n", .{});
    std.debug.print("\n", .{});
}

// Example 9: Parse balance data
fn exampleParseBalanceData(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 9: Parse balance data\n", .{});
    
    var adapter = try binance_ws.init(allocator, false, false);
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
    
    std.debug.print("  Event: {s}\n", .{balance.event_type});
    std.debug.print("  Balances ({d} assets):\n", .{balance.balances.len});
    for (balance.balances) |b| {
        std.debug.print("    {s}: {d:.8} free, {d:.8} locked\n", .{b.asset, b.free, b.locked});
    }
    std.debug.print("  ✓ Balance parsed\n", .{});
    std.debug.print("\n", .{});
}

// Example 10: Parse order data
fn exampleParseOrderData(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 10: Parse order data\n", .{});
    
    var adapter = try binance_ws.init(allocator, false, false);
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
    
    std.debug.print("  Event: {s}\n", .{order.event_type});
    std.debug.print("  Symbol: {s}\n", .{order.symbol});
    std.debug.print("  Client Order ID: {s}\n", .{order.client_order_id});
    std.debug.print("  Order ID: {d}\n", .{order.order_id});
    std.debug.print("  Side: {s}\n", .{if (order.side == .buy) "BUY" else "SELL"});
    std.debug.print("  Type: {s}\n", .{@tagName(order.order_type)});
    std.debug.print("  Status: {s}\n", .{@tagName(order.order_status)});
    std.debug.print("  Price: ${d:.2}\n", .{order.price});
    std.debug.print("  Quantity: {d:.4} BTC\n", .{order.original_quantity});
    std.debug.print("  Executed: {d:.4} BTC\n", .{order.executed_quantity});
    std.debug.print("  ✓ Order parsed\n", .{});
    std.debug.print("\n", .{});
}

// Example 11: Build combined subscription
fn exampleCombinedSubscription(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 11: Build combined subscription\n", .{});
    
    var adapter = try binance_ws.init(allocator, false, false);
    defer adapter.deinit();
    
    const streams = &[_][]const u8{
        "btcusdt@ticker",
        "btcusdt@depth10",
        "btcusdt@trade",
        "ethusdt@ticker"
    };
    
    const combined = try adapter.buildCombinedSubscription(streams);
    defer allocator.free(combined);
    
    std.debug.print("  Combined stream: {s}\n", .{combined});
    std.debug.print("  ✓ Combined subscription built\n", .{});
    std.debug.print("\n", .{});
}

// Example 12: Full workflow (commented out - requires network)
/*
fn exampleFullWorkflow(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 12: Full workflow with WebSocket connection\n", .{});
    
    // Create adapter
    var adapter = try binance_ws.init(allocator, false, false);
    defer adapter.deinit();
    
    // Build subscription
    const stream = try adapter.buildTickerMessage("BTC/USDT");
    defer allocator.free(stream);
    
    // Get full URL
    const url = try adapter.getFullUrl(stream);
    defer allocator.free(url);
    
    // Connect to WebSocket
    var client = try ws.WebSocketClient.init(allocator, url);
    defer client.deinit();
    
    try client.connect();
    std.debug.print("  Connected to {s}\n", .{url});
    
    // Receive messages
    while (true) {
        const message = try client.recv(allocator);
        defer message.deinit(allocator);
        
        if (message.typ == .text) {
            // Parse the ticker data
            const ticker = try adapter.parseTickerData(message.data);
            defer adapter.cleanupWebSocketTicker(&ticker);
            
            std.debug.print("  Ticker update: {s} = ${d:.2}\n", .{
                ticker.symbol,
                ticker.price
            });
        }
    }
}
*/
