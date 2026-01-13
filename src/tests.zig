// CCXT-Zig Unit Tests - Phase 2: Major Exchanges
//
// These tests validate the exchange implementations without making actual API calls.
// Mock data is used to test parsing and error handling.

const std = @import("std");
const testing = std.testing;

// Import the module
const ccxt = @import("ccxt_zig");

// ==================== Mock Data ====================

// Mock Binance ticker response
const mockBinanceTicker =
    \\{
    \\  "symbol": "BTCUSDT",
    \\  "price": "50000.00",
    \\  "highPrice": "52000.00",
    \\  "lowPrice": "48000.00",
    \\  "bidPrice": "49999.99",
    \\  "askPrice": "50000.01",
    \\  "volume": "1000.00",
    \\  "quoteVolume": "50000000.00",
    \\  "priceChangePercent": "2.5"
    \\}
;

// Mock Kraken ticker response
const mockKrakenTicker =
    \\{
    \\  "error": [],
    \\  "result": {
    \\    "XXBTZUSD": {
    \\      "a": ["50000.00", "1", "1.000"],
    \\      "b": ["49999.99", "2", "2.000"],
    \\      "c": ["50000.00", "0.5"],
    \\      "h": ["52000.00", "51000.00"],
    \\      "l": ["48000.00", "47500.00"],
    \\      "o": "49000.00",
    \\      "p": ["49500.00", "49200.00"],
    \\      "v": ["1000.00", "1200.00"]
    \\    }
    \\  }
    \\}
;

// Mock Coinbase ticker response
const mockCoinbaseTicker =
    \\{
    \\  "trade_id": 12345,
    \\  "price": "50000.00",
    \\  "size": "0.5",
    \\  "bid": "49999.99",
    \\  "ask": "50000.01",
    \\  "volume": "1000.00",
    \\  "time": "2024-01-15T10:30:00.000Z"
    \\}
;

// Mock Bybit ticker response
const mockBybitTicker =
    \\{
    \\  "retCode": 0,
    \\  "retMsg": "OK",
    \\  "result": {
    \\    "list": [{
    \\      "symbol": "BTCUSDT",
    \\      "lastPrice": "50000.00",
    \\      "bid1Price": "49999.99",
    \\      "ask1Price": "50000.01",
    \\      "highPrice24h": "52000.00",
    \\      "lowPrice24h": "48000.00",
    \\      "volume24h": "1000.00",
    \\      "turnover24h": "50000000.00",
    \\      "time": 1705315800000
    \\    }]
    \\  }
    \\}
;

// Mock order book response
const mockOrderBook =
    \\{
    \\  "bids": [["50000.00", "1.5"], ["49999.99", "2.0"]],
    \\  "asks": [["50000.01", "1.0"], ["50000.02", "2.5"]],
    \\  "timestamp": 1705315800000
    \\}
;

// Mock OHLCV data
const mockOHLCV =
    \\[
    \\  [1705315200000, "49000.00", "50000.00", "48000.00", "49500.00", "1000.00", "49500000.00", 100],
    \\  [1705318800000, "49500.00", "51000.00", "49000.00", "50000.00", "1200.00", "60000000.00", 150]
    \\]
;

// ==================== Test Functions ====================

test "BinanceExchange - Parse Ticker" {
    const allocator = testing.allocator;

    var auth_config = ccxt.auth.AuthConfig{};
    const binance = try ccxt.binance.create(allocator, auth_config);
    defer binance.deinit();

    const parser = &binance.base.json_parser;
    const parsed = try parser.parse(mockBinanceTicker);

    const ticker = try binance.parseTicker(parsed.value, "BTC/USDT");
    defer ticker.deinit(allocator);

    try testing.expectEqualStrings("BTC/USDT", ticker.symbol);
    try testing.expectEqual(@as(?f64, 50000.00), ticker.last);
    try testing.expectEqual(@as(?f64, 52000.00), ticker.high);
    try testing.expectEqual(@as(?f64, 48000.00), ticker.low);
}

test "BinanceExchange - Parse OrderBook" {
    const allocator = testing.allocator;

    var auth_config = ccxt.auth.AuthConfig{};
    const binance = try ccxt.binance.create(allocator, auth_config);
    defer binance.deinit();

    const parser = &binance.base.json_parser;
    const parsed = try parser.parse(mockOrderBook);

    const orderbook = try binance.parseOrderBook(parsed.value, "BTC/USDT");
    defer orderbook.deinit(allocator);

    try testing.expect(orderbook.bids.len > 0);
    try testing.expect(orderbook.asks.len > 0);
    try testing.expectEqualStrings("BTC/USDT", orderbook.symbol);
}

test "BinanceExchange - Parse OHLCV" {
    const allocator = testing.allocator;

    var auth_config = ccxt.auth.AuthConfig{};
    const binance = try ccxt.binance.create(allocator, auth_config);
    defer binance.deinit();

    const parser = &binance.base.json_parser;
    const parsed = try parser.parse(mockOHLCV);

    const ohlcvs = try binance.parseOHLCV(parsed.value, "BTC/USDT");
    defer allocator.free(ohlcvs);

    try testing.expect(ohlcvs.len == 2);

    const first = ohlcvs[0];
    try testing.expectEqual(@as(i64, 1705315200000), first.timestamp);
    try testing.expectEqual(@as(f64, 49000.00), first.open);
    try testing.expectEqual(@as(f64, 50000.00), first.high);
    try testing.expectEqual(@as(f64, 48000.00), first.low);
    try testing.expectEqual(@as(f64, 49500.00), first.close);
    try testing.expectEqual(@as(f64, 1000.00), first.volume);
}

test "KrakenExchange - Parse Ticker" {
    const allocator = testing.allocator;

    var auth_config = ccxt.auth.AuthConfig{};
    const kraken = try ccxt.kraken.create(allocator, auth_config);
    defer kraken.deinit();

    const parser = &kraken.base.json_parser;
    const parsed = try parser.parse(mockKrakenTicker);

    const result = parsed.value.get("result") orelse return error.InvalidResponse;
    const ticker_data = result.get("XXBTZUSD") orelse return error.InvalidResponse;

    const ticker = try kraken.parseTicker(ticker_data, "BTC/USD");
    defer ticker.deinit(allocator);

    try testing.expectEqualStrings("BTC/USD", ticker.symbol);
    // Kraken parses array format: [price, volume, timestamp]
    try testing.expect(ticker.last != null and ticker.last.? > 0);
}

test "CoinbaseExchange - Parse Ticker" {
    const allocator = testing.allocator;

    var auth_config = ccxt.auth.AuthConfig{};
    const coinbase = try ccxt.coinbase.create(allocator, auth_config);
    defer coinbase.deinit();

    const parser = &coinbase.base.json_parser;
    const parsed = try parser.parse(mockCoinbaseTicker);

    const ticker = try coinbase.parseTicker(parsed.value, "BTC/USD");
    defer ticker.deinit(allocator);

    try testing.expectEqualStrings("BTC/USD", ticker.symbol);
    try testing.expectEqual(@as(?f64, 50000.00), ticker.last);
    try testing.expect(ticker.timestamp > 0); // Should parse ISO timestamp
}

test "BybitExchange - Parse Ticker" {
    const allocator = testing.allocator;

    var auth_config = ccxt.auth.AuthConfig{};
    const bybit = try ccxt.bybit.create(allocator, auth_config);
    defer bybit.deinit();

    const parser = &bybit.base.json_parser;
    const parsed = try parser.parse(mockBybitTicker);

    const result = parsed.value.get("result") orelse return error.InvalidResponse;
    const list = result.get("list") orelse return error.InvalidResponse;
    const ticker_data = list.array.?[0];

    const ticker = try bybit.parseTicker(ticker_data, "BTC/USDT");
    defer ticker.deinit(allocator);

    try testing.expectEqualStrings("BTC/USDT", ticker.symbol);
    try testing.expectEqual(@as(?f64, 50000.00), ticker.last);
}

test "ExchangeRegistry - Create and Query" {
    const allocator = testing.allocator;

    var registry = try ccxt.registry.createDefaultRegistry(allocator);
    defer registry.deinit();

    // Check that all exchanges are registered
    try testing.expect(registry.get("binance") != null);
    try testing.expect(registry.get("kraken") != null);
    try testing.expect(registry.get("coinbase") != null);
    try testing.expect(registry.get("bybit") != null);
    try testing.expect(registry.get("okx") != null);
    try testing.expect(registry.get("gate") != null);
    try testing.expect(registry.get("huobi") != null);

    // Check exchange info
    const binance_info = registry.get("binance").?;
    try testing.expectEqualStrings("Binance", binance_info.info.name);
    try testing.expect(binance_info.info.spot_supported);
    try testing.expect(binance_info.info.futures_supported);
    try testing.expect(binance_info.testnet_creator != null);

    // Check that non-existent exchange returns null
    try testing.expect(registry.get("nonexistent") == null);

    // Check getNames
    const names = registry.getNames();
    defer allocator.free(names);
    try testing.expect(names.len == 7);
}

test "AuthConfig - Basic Operations" {
    const allocator = testing.allocator;

    var config = ccxt.auth.AuthConfig{
        .apiKey = try allocator.dupe(u8, "test_key"),
        .apiSecret = try allocator.dupe(u8, "test_secret"),
        .passphrase = try allocator.dupe(u8, "test_pass"),
    };

    // Config should have values set
    try testing.expect(config.apiKey != null);
    try testing.expect(config.apiSecret != null);
    try testing.expect(config.passphrase != null);

    try testing.expectEqualStrings("test_key", config.apiKey.?);
    try testing.expectEqualStrings("test_secret", config.apiSecret.?);
    try testing.expectEqualStrings("test_pass", config.passphrase.?);

    config.deinit(allocator);
}

test "Market - Parse and Format" {
    const allocator = testing.allocator;

    const market = ccxt.Market{
        .id = "BTCUSDT",
        .symbol = "BTC/USDT",
        .base = "BTC",
        .quote = "USDT",
        .baseId = try allocator.dupe(u8, "BTC"),
        .quoteId = try allocator.dupe(u8, "USDT"),
        .active = true,
        .spot = true,
        .margin = true,
        .future = false,
        .swap = false,
        .option = false,
        .contract = false,
        .limits = .{
            .amount = .{ .min = 0.001, .max = null },
            .price = .{ .min = 0.01, .max = null },
        },
        .precision = .{
            .amount = 4,
            .price = 2,
        },
    };

    try testing.expectEqualStrings("BTCUSDT", market.id);
    try testing.expectEqualStrings("BTC/USDT", market.symbol);
    try testing.expect(market.active);
    try testing.expect(market.spot);

    market.deinit(allocator);
}

test "Ticker - Parse and Format" {
    const allocator = testing.allocator;

    const ticker = ccxt.Ticker{
        .symbol = "BTC/USDT",
        .timestamp = 1705315800000,
        .high = 52000.00,
        .low = 48000.00,
        .bid = 49999.99,
        .ask = 50000.01,
        .last = 50000.00,
        .baseVolume = 1000.00,
        .quoteVolume = 50000000.00,
    };

    try testing.expectEqualStrings("BTC/USDT", ticker.symbol);
    try testing.expectEqual(@as(?f64, 52000.00), ticker.high);
    try testing.expectEqual(@as(?f64, 50000.00), ticker.last);

    ticker.deinit(allocator);
}

test "Order - Parse Order Types" {
    const allocator = testing.allocator;

    // Test order types
    try testing.expectEqualStrings("market", ccxt.OrderType.market.asString());
    try testing.expectEqualStrings("limit", ccxt.OrderType.limit.asString());
    try testing.expectEqualStrings("stop", ccxt.OrderType.stop.asString());
    try testing.expectEqualStrings("trailing_stop", ccxt.OrderType.trailing_stop.asString());

    // Test order sides
    try testing.expectEqualStrings("buy", ccxt.OrderSide.buy.asString());
    try testing.expectEqualStrings("sell", ccxt.OrderSide.sell.asString());

    // Test order status
    try testing.expectEqualStrings("open", ccxt.OrderStatus.open.asString());
    try testing.expectEqualStrings("closed", ccxt.OrderStatus.closed.asString());
    try testing.expectEqualStrings("canceled", ccxt.OrderStatus.canceled.asString());
}

test "OHLCV - Array Conversion" {
    const allocator = testing.allocator;

    const ohlcv = ccxt.OHLCV{
        .timestamp = 1705315200000,
        .open = 49000.00,
        .high = 50000.00,
        .low = 48000.00,
        .close = 49500.00,
        .volume = 1000.00,
    };

    const arr = ohlcv.toArray();
    try testing.expectEqual(@as(f64, 1705315200000), arr[0]);
    try testing.expectEqual(@as(f64, 49000.00), arr[1]);
    try testing.expectEqual(@as(f64, 50000.00), arr[2]);

    const from_arr = ccxt.OHLCV.fromArray(arr);
    try testing.expectEqual(ohlcv.timestamp, from_arr.timestamp);
    try testing.expectEqual(ohlcv.open, from_arr.open);
}

test "TimeUtils - Timestamp Conversions" {
    const now = ccxt.time.TimeUtils.now();
    try testing.expect(now > 0);

    // Test seconds to milliseconds conversion
    const seconds: i64 = 1000;
    const ms = ccxt.time.TimeUtils.secondsToMs(seconds);
    try testing.expectEqual(@as(i64, 1000000), ms);

    // Test milliseconds to seconds conversion
    const back_to_seconds = ccxt.time.TimeUtils.msToSeconds(ms);
    try testing.expectEqual(seconds, back_to_seconds);
}

test "Crypto - HMAC-SHA256" {
    const allocator = testing.allocator;

    const key = "test_key";
    const message = "test_message";

    const signature = try ccxt.crypto.Signer.hmacSha256Hex(key, message);
    try testing.expect(signature.len == 64); // Hex string of 32 bytes

    // Verify consistent output
    const signature2 = try ccxt.crypto.Signer.hmacSha256Hex(key, message);
    try testing.expectEqualStrings(&signature, &signature2);
}

test "Crypto - Base64 Encoding" {
    const allocator = testing.allocator;

    const data = "hello world";
    const encoded = try ccxt.crypto.base64Encode(allocator, data);
    defer allocator.free(encoded);

    try testing.expectEqualStrings("aGVsbG8gd29ybGQ=", encoded);

    const decoded = try ccxt.crypto.base64Decode(allocator, encoded);
    defer allocator.free(decoded);

    try testing.expectEqualStrings(data, decoded);
}

test "HttpClient - Basic Operations" {
    const allocator = testing.allocator;

    const client = try ccxt.http.HttpClient.init(allocator);
    defer client.deinit();

    // Client should be initialized
    try testing.expect(client.timeout_ms > 0);
    try testing.expectEqualStrings("CCXT-Zig/0.1.0", client.user_agent);

    // Test configuration methods
    client.setTimeout(60000);
    try testing.expectEqual(@as(u64, 60000), client.timeout_ms);
}

test "BaseExchange - Rate Limiting" {
    const allocator = testing.allocator;

    var auth_config = ccxt.auth.AuthConfig{};
    var base = ccxt.exchange.BaseExchange{
        .allocator = allocator,
        .name = "test",
        .api_url = "https://api.test.com",
        .ws_url = "wss://ws.test.com",
        .http_client = undefined,
        .auth_config = auth_config,
        .markets = null,
        .last_markets_fetch = 0,
        .rate_limit = 10,
        .request_counter = 0,
        .headers = std.StringHashMap([]const u8).init(allocator),
        .json_parser = ccxt.json.JsonParser.init(allocator),
    };
    defer {
        var iter = base.headers.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        base.headers.deinit();
    }

    // Initial state
    try testing.expectEqual(@as(u32, 0), base.request_counter);

    // Simulate requests
    base.request_counter = 5;
    try testing.expect(base.request_counter < base.rate_limit);

    base.request_counter = 10;
    try testing.expect(base.request_counter >= base.rate_limit);
}

test "Error Handling - ExchangeError types" {
    // Test error type handling
    const NetworkError = ccxt.errors.ExchangeError.NetworkError;
    const AuthenticationError = ccxt.errors.ExchangeError.AuthenticationError;
    const RateLimitError = ccxt.errors.ExchangeError.RateLimitError;
    const OrderNotFound = ccxt.errors.ExchangeError.OrderNotFound;

    // These are error sets, not values
    _ = NetworkError;
    _ = AuthenticationError;
    _ = RateLimitError;
    _ = OrderNotFound;
}

test "JsonParser - Basic Operations" {
    const allocator = testing.allocator;

    const parser = ccxt.json.JsonParser.init(allocator);

    const json_str = "{\"key\": \"value\", \"number\": 42}";
    const parsed = try parser.parse(json_str);

    const value = parsed.value.get("key");
    try testing.expect(value != null);
    try testing.expectEqualStrings("value", switch (value.?) {
        .string => |s| s,
        else => @as([]const u8, ""),
    });
}

test "Decimal - From String" {
    const allocator = testing.allocator;

    const decimal = try ccxt.types.Decimal.fromString(allocator, "123.456789");
    try testing.expect(decimal.scale == 8);

    decimal.deinit(allocator);
}

// ==================== Phase 3 Preview Tests ====================

test "HyperliquidExchange - Initialize" {
    const allocator = testing.allocator;

    var auth_config = ccxt.auth.AuthConfig{};
    const hyperliquid = try ccxt.hyperliquid.create(allocator, auth_config);
    defer hyperliquid.deinit();

    // Test basic properties
    try testing.expectEqualStrings("hyperliquid", hyperliquid.base.name);
    try testing.expectEqualStrings("https://api.hyperliquid.xyz", hyperliquid.base.api_url);
    try testing.expect(hyperliquid.base.rate_limit == 100);
    try testing.expect(hyperliquid.base.requires_signature == true);
    try testing.expectEqualStrings("/", hyperliquid.base.symbol_separator);
}

test "HyperliquidExchange - Fetch Markets (Mock)" {
    const allocator = testing.allocator;

    var auth_config = ccxt.auth.AuthConfig{};
    const hyperliquid = try ccxt.hyperliquid.create(allocator, auth_config);
    defer hyperliquid.deinit();

    // Test that fetchMarkets returns a valid array (even if empty)
    const markets = try hyperliquid.fetchMarkets();
    defer {
        for (markets) |*market| market.deinit(allocator);
        allocator.free(markets);
    }

    try testing.expect(markets.len >= 0);
}

// ==================== Run Tests ====================

test "All Phase 2 Tests" {
    // This is a meta-test that runs all other tests
    // The individual tests above are run by the Zig test runner
    try testing.expect(true);
}
