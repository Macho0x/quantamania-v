const std = @import("std");
const exchange = @import("../base/exchange.zig");
const auth = @import("../base/auth.zig");
const errors = @import("../base/errors.zig");
const http = @import("../base/http.zig");
const json = @import("../utils/json.zig");
const time = @import("../utils/time.zig");
const crypto = @import("../utils/crypto.zig");
const precision_utils = @import("../utils/precision.zig");

// Import models
const Market = @import("../models/market.zig").Market;
const MarketPrecision = @import("../models/market.zig").MarketPrecision;
const Ticker = @import("../models/ticker.zig").Ticker;
const OrderBook = @import("../models/orderbook.zig").OrderBook;
const Order = @import("../models/order.zig").Order;
const OrderType = @import("../models/order.zig").OrderType;
const OrderSide = @import("../models/order.zig").OrderSide;
const OrderStatus = @import("../models/order.zig").OrderStatus;
const Balance = @import("../models/balance.zig").Balance;
const Trade = @import("../models/trade.zig").Trade;
const OHLCV = @import("../models/ohlcv.zig").OHLCV;
const Position = @import("../models/position.zig").Position;
const types = @import("../base/types.zig");

// KuCoin Exchange Implementation
// Exchange-specific tags: baseIncrement, quoteIncrement, baseMinSize, quoteMinSize, priceIncrement
pub const KucoinExchange = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    api_key: ?[]const u8,
    secret_key: ?[]const u8,
    passphrase: ?[]const u8,
    testnet: bool,
    precision_config: precision_utils.ExchangePrecisionConfig,

    // API endpoints
    const API_URL = "https://api.kucoin.com";
    const API_URL_FUTURES = "https://api-futures.kucoin.com";
    const TESTNET_URL = "https://openapi-sandbox.kucoin.com";
    const WS_URL = "wss://ws-api.kucoin.com";

    // KuCoin-specific tags
    pub const KucoinTags = struct {
        base_increment: []const u8 = "baseIncrement",      // Minimum amount precision
        quote_increment: []const u8 = "quoteIncrement",    // Minimum price precision (tick size)
        base_min_size: []const u8 = "baseMinSize",         // Minimum order amount
        quote_min_size: []const u8 = "quoteMinSize",       // Minimum order cost
        base_max_size: []const u8 = "baseMaxSize",         // Maximum order amount
        quote_max_size: []const u8 = "quoteMaxSize",       // Maximum order cost
        price_increment: []const u8 = "priceIncrement",    // Price tick size
        price_limit_rate: []const u8 = "priceLimitRate",   // Price deviation limit
        enable_trading: []const u8 = "enableTrading",      // Is trading enabled
    };

    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig, testnet: bool) !*KucoinExchange {
        const self = try allocator.create(KucoinExchange);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.api_key = auth_config.apiKey;
        self.secret_key = auth_config.apiSecret;
        self.passphrase = auth_config.passphrase;
        self.testnet = testnet;
        self.precision_config = precision_utils.ExchangePrecisionConfig.kucoin();

        var http_client = try http.HttpClient.init(allocator);
        errdefer http_client.deinit();

        const base_name = try allocator.dupe(u8, "kucoin");
        const base_url = if (testnet) TESTNET_URL else API_URL;
        const base_url_copy = try allocator.dupe(u8, base_url);
        const ws_url_copy = try allocator.dupe(u8, WS_URL);

        self.base = exchange.BaseExchange{
            .allocator = allocator,
            .name = base_name,
            .api_url = base_url_copy,
            .ws_url = ws_url_copy,
            .http_client = http_client,
            .auth_config = auth_config,
            .markets = null,
            .last_markets_fetch = 0,
            .rate_limit = 2000, // 2000 requests per 10 seconds
            .rate_limit_window_ms = 10000,
            .request_counter = 0,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .json_parser = json.JsonParser.init(allocator),
        };

        // Add default headers
        try self.base.headers.put(try allocator.dupe(u8, "User-Agent"), try allocator.dupe(u8, self.base.user_agent));
        try self.base.headers.put(try allocator.dupe(u8, "Accept"), try allocator.dupe(u8, "application/json"));

        return self;
    }

    pub fn deinit(self: *KucoinExchange) void {
        if (self.api_key) |k| self.allocator.free(k);
        if (self.secret_key) |s| self.allocator.free(s);
        if (self.passphrase) |p| self.allocator.free(p);
        self.base.deinit();
        self.allocator.destroy(self);
    }

    // Sign request for private endpoints (KC-API-SIGN, KC-API-TIMESTAMP, KC-API-KEY, KC-API-PASSPHRASE, KC-API-KEY-VERSION)
    fn signRequest(
        self: *KucoinExchange,
        method: []const u8,
        endpoint: []const u8,
        query_params: ?std.StringHashMap([]const u8),
        body: ?[]const u8,
    ) !std.StringHashMap([]const u8) {
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        errdefer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        if (self.api_key == null or self.secret_key == null or self.passphrase == null) {
            return headers;
        }

        const timestamp = time.TimeUtils.now();
        const timestamp_str = try std.fmt.allocPrint(self.allocator, "{d}", .{timestamp});

        // Build sign string: timestamp + method + endpoint + body
        var sign_string = std.ArrayList(u8).init(self.allocator);
        defer sign_string.deinit();

        try sign_string.appendSlice(timestamp_str);
        try sign_string.appendSlice(method);
        try sign_string.appendSlice(endpoint);
        
        if (body) |b| {
            try sign_string.appendSlice(b);
        }

        // Generate signature
        const signature = try crypto.Signer.hmacSha256Base64(self.secret_key.?, sign_string.items);
        const passphrase_sign = try crypto.Signer.hmacSha256Base64(self.secret_key.?, self.passphrase.?);

        try headers.put(try self.allocator.dupe(u8, "KC-API-KEY"), try self.allocator.dupe(u8, self.api_key.?));
        try headers.put(try self.allocator.dupe(u8, "KC-API-SIGN"), try self.allocator.dupe(u8, &signature));
        try headers.put(try self.allocator.dupe(u8, "KC-API-TIMESTAMP"), timestamp_str);
        try headers.put(try self.allocator.dupe(u8, "KC-API-PASSPHRASE"), try self.allocator.dupe(u8, &passphrase_sign));
        try headers.put(try self.allocator.dupe(u8, "KC-API-KEY-VERSION"), try self.allocator.dupe(u8, "2"));

        return headers;
    }

    // Public API: Fetch markets
    pub fn fetchMarkets(self: *KucoinExchange) ![]Market {
        const endpoint = "/api/v1/symbols";
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        const root = parsed.value;
        const data_obj = root.object.get("data") orelse return error.InvalidResponse;
        const markets_array = switch (data_obj) {
            .array => |a| a.items,
            else => return error.InvalidResponse,
        };

        var result = std.ArrayList(Market).init(self.allocator);
        errdefer result.deinit();

        for (markets_array) |market_data| {
            const obj = switch (market_data) {
                .object => |o| o,
                else => continue,
            };

            const symbol_str = obj.get("symbol") orelse continue;
            const symbol = switch (symbol_str) {
                .string => |s| s,
                else => continue,
            };

            const base_currency_str = obj.get("baseCurrency") orelse continue;
            const base = switch (base_currency_str) {
                .string => |s| s,
                else => continue,
            };

            const quote_currency_str = obj.get("quoteCurrency") orelse continue;
            const quote = switch (quote_currency_str) {
                .string => |s| s,
                else => continue,
            };

            const enable_trading_val = obj.get("enableTrading") orelse continue;
            const active = switch (enable_trading_val) {
                .bool => |b| b,
                else => true,
            };

            // Parse KuCoin-specific tags
            const base_increment = parser.getFloat(obj.get("baseIncrement") orelse .{ .float = 0.00000001 }, 0.00000001);
            const quote_increment = parser.getFloat(obj.get("quoteIncrement") orelse .{ .float = 0.01 }, 0.01);
            const base_min_size = parser.getFloat(obj.get("baseMinSize") orelse .{ .float = 0 }, 0);
            const base_max_size = parser.getFloat(obj.get("baseMaxSize") orelse .{ .float = 0 }, 0);
            const quote_min_size = parser.getFloat(obj.get("quoteMinSize") orelse .{ .float = 0 }, 0);
            const quote_max_size = parser.getFloat(obj.get("quoteMaxSize") orelse .{ .float = 0 }, 0);

            // Calculate precision from increment values
            const amount_precision = precision_utils.PrecisionUtils.init(self.allocator).getDecimalPlaces(base_increment);
            const price_precision = precision_utils.PrecisionUtils.init(self.allocator).getDecimalPlaces(quote_increment);

            const market = Market{
                .id = try self.allocator.dupe(u8, symbol),
                .symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base, quote }),
                .base = try self.allocator.dupe(u8, base),
                .quote = try self.allocator.dupe(u8, quote),
                .baseId = try self.allocator.dupe(u8, base),
                .quoteId = try self.allocator.dupe(u8, quote),
                .active = active,
                .type = .spot,
                .spot = true,
                .margin = false,
                .future = false,
                .swap = false,
                .option = false,
                .contract = false,
                .settle = null,
                .settleId = null,
                .limits = .{
                    .amount = .{ .min = if (base_min_size > 0) base_min_size else null, .max = if (base_max_size > 0) base_max_size else null },
                    .price = .{ .min = null, .max = null },
                    .cost = .{ .min = if (quote_min_size > 0) quote_min_size else null, .max = if (quote_max_size > 0) quote_max_size else null },
                    .leverage = .{ .min = null, .max = null },
                },
                .precision = MarketPrecision{
                    .amount = amount_precision,
                    .price = price_precision,
                    .base = amount_precision,
                    .quote = price_precision,
                },
                .info = null,
                .taker = parser.getFloat(obj.get("takerFeeRate") orelse .{ .float = 0.001 }, 0.001),
                .maker = parser.getFloat(obj.get("makerFeeRate") orelse .{ .float = 0.001 }, 0.001),
                .percentage = true,
                .tierBased = false,
            };

            try result.append(market);
        }

        return result.toOwnedSlice();
    }

    // Public API: Fetch ticker
    pub fn fetchTicker(self: *KucoinExchange, symbol: []const u8) !Ticker {
        const market = self.base.findMarket(symbol) orelse return error.SymbolNotFound;

        const endpoint = try std.fmt.allocPrint(self.allocator, "/api/v1/market/stats?symbol={s}", .{market.id});
        defer self.allocator.free(endpoint);

        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        const root = parsed.value;
        const data_obj = root.object.get("data") orelse return error.InvalidResponse;

        return try self.parseTicker(data_obj, symbol);
    }

    fn parseTicker(self: *KucoinExchange, obj: std.json.Value, symbol: []const u8) !Ticker {
        var parser = json.JsonParser.init(self.allocator);
        
        const symbol_copy = try self.allocator.dupe(u8, symbol);
        const last = parser.getFloat(obj.object.get("last") orelse .{ .float = 0 }, 0);
        const high = parser.getFloat(obj.object.get("high") orelse .{ .float = 0 }, 0);
        const low = parser.getFloat(obj.object.get("low") orelse .{ .float = 0 }, 0);
        const vol = parser.getFloat(obj.object.get("vol") orelse .{ .float = 0 }, 0);
        const volume_value = parser.getFloat(obj.object.get("volValue") orelse .{ .float = 0 }, 0);
        const change_rate = parser.getFloat(obj.object.get("changeRate") orelse .{ .float = 0 }, 0);

        return Ticker{
            .symbol = symbol_copy,
            .timestamp = time.TimeUtils.now(),
            .high = if (high > 0) high else null,
            .low = if (low > 0) low else null,
            .bid = null,
            .bidVolume = null,
            .ask = null,
            .askVolume = null,
            .vwap = null,
            .open = null,
            .close = if (last > 0) last else null,
            .last = if (last > 0) last else null,
            .previousClose = null,
            .change = null,
            .percentage = if (change_rate != 0) change_rate * 100 else null,
            .average = null,
            .baseVolume = if (vol > 0) vol else null,
            .quoteVolume = if (volume_value > 0) volume_value else null,
            .info = null,
        };
    }

    // Public API: Fetch order book
    pub fn fetchOrderBook(self: *KucoinExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        const market = self.base.findMarket(symbol) orelse return error.SymbolNotFound;

        const limit_val = if (limit) |l| l else 100;
        const endpoint = try std.fmt.allocPrint(self.allocator, "/api/v1/market/orderbook/level2_{d}?symbol={s}", .{ limit_val, market.id });
        defer self.allocator.free(endpoint);

        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        const root = parsed.value;
        const data_obj = root.object.get("data") orelse return error.InvalidResponse;

        return try self.parseOrderBook(data_obj, symbol);
    }

    fn parseOrderBook(self: *KucoinExchange, obj: std.json.Value, symbol: []const u8) !OrderBook {
        var parser = json.JsonParser.init(self.allocator);
        const timestamp = time.TimeUtils.now();

        // Parse bids
        var bids = std.ArrayList(OrderBook.OrderBookEntry).init(self.allocator);
        defer bids.deinit();

        if (obj.object.get("bids")) |bids_val| {
            if (bids_val == .array) {
                for (bids_val.array.items) |bid| {
                    if (bid == .array and bid.array.items.len >= 2) {
                        const price_str = switch (bid.array.items[0]) {
                            .string => |s| s,
                            else => continue,
                        };
                        const amount_str = switch (bid.array.items[1]) {
                            .string => |s| s,
                            else => continue,
                        };

                        const price = std.fmt.parseFloat(f64, price_str) catch continue;
                        const amount = std.fmt.parseFloat(f64, amount_str) catch continue;

                        try bids.append(.{ .price = price, .amount = amount, .timestamp = timestamp });
                    }
                }
            }
        }

        // Parse asks
        var asks = std.ArrayList(OrderBook.OrderBookEntry).init(self.allocator);
        defer asks.deinit();

        if (obj.object.get("asks")) |asks_val| {
            if (asks_val == .array) {
                for (asks_val.array.items) |ask| {
                    if (ask == .array and ask.array.items.len >= 2) {
                        const price_str = switch (ask.array.items[0]) {
                            .string => |s| s,
                            else => continue,
                        };
                        const amount_str = switch (ask.array.items[1]) {
                            .string => |s| s,
                            else => continue,
                        };

                        const price = std.fmt.parseFloat(f64, price_str) catch continue;
                        const amount = std.fmt.parseFloat(f64, amount_str) catch continue;

                        try asks.append(.{ .price = price, .amount = amount, .timestamp = timestamp });
                    }
                }
            }
        }

        const datetime = try self.base.parseDatetime(self.allocator, timestamp);

        return OrderBook{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = timestamp,
            .datetime = datetime,
            .bids = try bids.toOwnedSlice(),
            .asks = try asks.toOwnedSlice(),
            .nonce = null,
        };
    }

    // Public API: Fetch OHLCV
    pub fn fetchOHLCV(self: *KucoinExchange, symbol: []const u8, timeframe: []const u8, since: ?i64, limit: ?u32) ![]OHLCV {
        const market_symbol = try self.base.marketId(symbol);
        defer self.allocator.free(market_symbol);

        var endpoint = std.ArrayList(u8).init(self.allocator);
        defer endpoint.deinit();

        try endpoint.appendSlice("/api/v1/market/candles?symbol=");
        try endpoint.appendSlice(market_symbol);
        try endpoint.appendSlice("&type=");
        try endpoint.appendSlice(timeframe);

        if (since) |s| {
            const since_str = try std.fmt.allocPrint(self.allocator, "&startAt={d}", .{@divFloor(s, 1000)});
            defer self.allocator.free(since_str);
            try endpoint.appendSlice(since_str);
        }

        if (limit) |l| {
            const limit_str = try std.fmt.allocPrint(self.allocator, "&limit={d}", .{l});
            defer self.allocator.free(limit_str);
            try endpoint.appendSlice(limit_str);
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint.items });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        const root = parsed.value;
        const data_obj = root.object.get("data") orelse return error.InvalidResponse;

        return try self.parseOHLCV(data_obj);
    }

    fn parseOHLCV(self: *KucoinExchange, data: std.json.Value) ![]OHLCV {
        var result = std.ArrayList(OHLCV).init(self.allocator);
        errdefer result.deinit();

        if (data == .array) {
            for (data.array.items) |candle| {
                if (candle == .array and candle.array.items.len >= 6) {
                    const timestamp_str = switch (candle.array.items[0]) {
                        .string => |s| s,
                        else => continue,
                    };
                    const open_str = switch (candle.array.items[1]) {
                        .string => |s| s,
                        else => continue,
                    };
                    const close_str = switch (candle.array.items[2]) {
                        .string => |s| s,
                        else => continue,
                    };
                    const high_str = switch (candle.array.items[3]) {
                        .string => |s| s,
                        else => continue,
                    };
                    const low_str = switch (candle.array.items[4]) {
                        .string => |s| s,
                        else => continue,
                    };
                    const volume_str = switch (candle.array.items[5]) {
                        .string => |s| s,
                        else => continue,
                    };

                    const timestamp = (std.fmt.parseInt(i64, timestamp_str, 10) catch continue) * 1000;
                    const open = std.fmt.parseFloat(f64, open_str) catch continue;
                    const high = std.fmt.parseFloat(f64, high_str) catch continue;
                    const low = std.fmt.parseFloat(f64, low_str) catch continue;
                    const close = std.fmt.parseFloat(f64, close_str) catch continue;
                    const volume = std.fmt.parseFloat(f64, volume_str) catch continue;

                    try result.append(OHLCV{
                        .timestamp = timestamp,
                        .open = open,
                        .high = high,
                        .low = low,
                        .close = close,
                        .volume = volume,
                    });
                }
            }
        }

        return result.toOwnedSlice();
    }

    // Public API: Fetch trades
    pub fn fetchTrades(self: *KucoinExchange, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        _ = since;
        _ = limit;

        const market = self.base.findMarket(symbol) orelse return error.SymbolNotFound;

        const endpoint = try std.fmt.allocPrint(self.allocator, "/api/v1/market/histories?symbol={s}", .{market.id});
        defer self.allocator.free(endpoint);

        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        const root = parsed.value;
        const data_obj = root.object.get("data") orelse return error.InvalidResponse;

        return try self.parseTrades(data_obj, symbol);
    }

    fn parseTrades(self: *KucoinExchange, data: std.json.Value, symbol: []const u8) ![]Trade {
        var result = std.ArrayList(Trade).init(self.allocator);
        errdefer result.deinit();

        if (data == .array) {
            for (data.array.items) |trade_obj| {
                const obj = switch (trade_obj) {
                    .object => |o| o,
                    else => continue,
                };

                var parser = json.JsonParser.init(self.allocator);

                const sequence = parser.getStringValue(obj.get("sequence"), "0");
                const price = parser.getFloat(obj.get("price") orelse .{ .float = 0 }, 0);
                const size = parser.getFloat(obj.get("size") orelse .{ .float = 0 }, 0);
                const side_str = parser.getStringValue(obj.get("side"), "buy");
                const timestamp = parser.getInt(obj.get("time") orelse .{ .integer = 0 }, 0) / 1000000;

                const side: []const u8 = if (std.mem.eql(u8, side_str, "sell")) "sell" else "buy";

                try result.append(Trade{
                    .id = try self.allocator.dupe(u8, sequence),
                    .order = null,
                    .info = null,
                    .timestamp = timestamp,
                    .datetime = try time.TimeUtils.iso8601(self.allocator, timestamp),
                    .symbol = try self.allocator.dupe(u8, symbol),
                    .type = .spot,
                    .side = try self.allocator.dupe(u8, side),
                    .takerOrMaker = null,
                    .price = price,
                    .amount = size,
                    .cost = price * size,
                    .fee = null,
                });
            }
        }

        return result.toOwnedSlice();
    }

    // Private API: Fetch balance
    pub fn fetchBalance(self: *KucoinExchange) ![]Balance {
        const endpoint = "/api/v1/accounts";
        const headers = try self.signRequest("GET", endpoint, null, null);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, headers);
        defer self.allocator.free(response);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response);
        defer parsed.deinit();

        const root = parsed.value;
        const data_obj = root.object.get("data") orelse return error.InvalidResponse;

        return try self.parseBalance(data_obj);
    }

    fn parseBalance(self: *KucoinExchange, data: std.json.Value) ![]Balance {
        var result = std.ArrayList(Balance).init(self.allocator);
        errdefer result.deinit();

        if (data == .array) {
            for (data.array.items) |account_obj| {
                const obj = switch (account_obj) {
                    .object => |o| o,
                    else => continue,
                };

                var parser = json.JsonParser.init(self.allocator);

                const currency = parser.getStringValue(obj.get("currency"), "");
                const available = parser.getFloat(obj.get("available") orelse .{ .float = 0 }, 0);
                const holds = parser.getFloat(obj.get("holds") orelse .{ .float = 0 }, 0);

                try result.append(Balance{
                    .currency = try self.allocator.dupe(u8, currency),
                    .free = available,
                    .used = holds,
                    .total = available + holds,
                });
            }
        }

        return result.toOwnedSlice();
    }

    // Private API: Create order
    pub fn createOrder(self: *KucoinExchange, symbol: []const u8, order_type: OrderType, side: OrderSide, amount: f64, price: ?f64, params: ?std.StringHashMap([]const u8)) !Order {
        const market_symbol = try self.base.marketId(symbol);
        defer self.allocator.free(market_symbol);

        const endpoint = "/api/v1/orders";

        // Build request body
        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        const client_oid = try std.fmt.allocPrint(self.allocator, "kucoin_{d}", .{time.TimeUtils.now()});
        defer self.allocator.free(client_oid);

        try body.appendSlice("{\"clientOid\":\"");
        try body.appendSlice(client_oid);
        try body.appendSlice("\",\"symbol\":\"");
        try body.appendSlice(market_symbol);
        try body.appendSlice("\",\"side\":\"");
        try body.appendSlice(if (side == .buy) "buy" else "sell");
        try body.appendSlice("\",\"type\":\"");
        try body.appendSlice(if (order_type == .market) "market" else "limit");
        try body.appendSlice("\",\"size\":\"");

        const size_str = try std.fmt.allocPrint(self.allocator, "{d}", .{amount});
        defer self.allocator.free(size_str);
        try body.appendSlice(size_str);
        try body.appendSlice("\"");

        if (price) |p| {
            try body.appendSlice(",\"price\":\"");
            const price_str = try std.fmt.allocPrint(self.allocator, "{d}", .{p});
            defer self.allocator.free(price_str);
            try body.appendSlice(price_str);
            try body.appendSlice("\"");
        }

        try body.appendSlice("}");

        const headers = try self.signRequest("POST", endpoint, null, body.items);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint });
        defer self.allocator.free(url);

        const response = try self.base.http_client.post(url, headers, body.items);
        defer self.allocator.free(response);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response);
        defer parsed.deinit();

        const root = parsed.value;
        const data_obj = root.object.get("data") orelse return error.InvalidResponse;

        const order_id = parser.getString(data_obj.object.get("orderId"), "");

        return Order{
            .id = try self.allocator.dupe(u8, order_id orelse ""),
            .clientOrderId = try self.allocator.dupe(u8, client_oid),
            .timestamp = time.TimeUtils.now(),
            .datetime = try time.TimeUtils.iso8601(self.allocator, time.TimeUtils.now()),
            .lastTradeTimestamp = null,
            .status = .open,
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = order_type,
            .side = side,
            .price = price,
            .amount = amount,
            .filled = 0.0,
            .remaining = amount,
            .cost = if (price) |p| p * amount else null,
            .trades = null,
            .fee = null,
            .info = data_obj,
        };
    }

    // Private API: Cancel order
    pub fn cancelOrder(self: *KucoinExchange, order_id: []const u8, symbol: ?[]const u8) !void {
        const endpoint = try std.fmt.allocPrint(self.allocator, "/api/v1/orders/{s}", .{order_id});
        defer self.allocator.free(endpoint);

        const headers = try self.signRequest("DELETE", endpoint, null, null);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint });
        defer self.allocator.free(url);

        const response = try self.base.http_client.delete(url, headers);
        defer self.allocator.free(response);
    }

    // Private API: Fetch order
    pub fn fetchOrder(self: *KucoinExchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        const endpoint = try std.fmt.allocPrint(self.allocator, "/api/v1/orders/{s}", .{order_id});
        defer self.allocator.free(endpoint);

        const headers = try self.signRequest("GET", endpoint, null, null);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, headers);
        defer self.allocator.free(response);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response);
        defer parsed.deinit();

        const root = parsed.value;
        const data_obj = root.object.get("data") orelse return error.InvalidResponse;

        return try self.parseOrder(data_obj);
    }

    fn parseOrder(self: *KucoinExchange, obj: std.json.Value) !Order {
        var parser = json.JsonParser.init(self.allocator);

        const order_id = parser.getString(obj.object.get("id"), "");
        const client_oid = parser.getString(obj.object.get("clientOid"), "");
        const symbol_id = parser.getString(obj.object.get("symbol"), "");
        const side_str = parser.getString(obj.object.get("side"), "buy");
        const type_str = parser.getString(obj.object.get("type"), "limit");
        const price = parser.getFloat(obj.object.get("price") orelse .{ .float = 0 }, 0);
        const size = parser.getFloat(obj.object.get("size") orelse .{ .float = 0 }, 0);
        const deal_size = parser.getFloat(obj.object.get("dealSize") orelse .{ .float = 0 }, 0);
        const is_active = parser.getBool(obj.object.get("isActive") orelse .{ .bool = false }, false);
        const created_at = parser.getInt(obj.object.get("createdAt") orelse .{ .integer = 0 }, 0);

        const side: OrderSide = if (std.mem.eql(u8, side_str orelse "buy", "sell")) .sell else .buy;
        const order_type: OrderType = if (std.mem.eql(u8, type_str orelse "limit", "market")) .market else .limit;
        const status: OrderStatus = if (is_active) .open else if (deal_size > 0) .closed else .canceled;

        return Order{
            .id = try self.allocator.dupe(u8, order_id orelse ""),
            .clientOrderId = if (client_oid) |c| try self.allocator.dupe(u8, c) else null,
            .timestamp = created_at,
            .datetime = try time.TimeUtils.iso8601(self.allocator, created_at),
            .lastTradeTimestamp = null,
            .status = status,
            .symbol = try self.allocator.dupe(u8, symbol_id orelse ""),
            .type = order_type,
            .side = side,
            .price = if (price > 0) price else null,
            .amount = size,
            .filled = deal_size,
            .remaining = size - deal_size,
            .cost = if (price > 0) price * deal_size else null,
            .trades = null,
            .fee = null,
            .info = obj,
        };
    }

    // Private API: Fetch open orders
    pub fn fetchOpenOrders(self: *KucoinExchange, symbol: ?[]const u8) ![]Order {
        var endpoint = std.ArrayList(u8).init(self.allocator);
        defer endpoint.deinit();

        try endpoint.appendSlice("/api/v1/orders?status=active");

        if (symbol) |s| {
            const market_symbol = try self.base.marketId(s);
            defer self.allocator.free(market_symbol);

            try endpoint.appendSlice("&symbol=");
            try endpoint.appendSlice(market_symbol);
        }

        const headers = try self.signRequest("GET", endpoint.items, null, null);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint.items });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, headers);
        defer self.allocator.free(response);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response);
        defer parsed.deinit();

        const root = parsed.value;
        const data_obj = root.object.get("data") orelse return error.InvalidResponse;
        const items_obj = data_obj.object.get("items") orelse return error.InvalidResponse;

        return try self.parseOrders(items_obj);
    }

    // Private API: Fetch closed orders
    pub fn fetchClosedOrders(self: *KucoinExchange, symbol: ?[]const u8, since: ?i64, limit: ?u32) ![]Order {
        var endpoint = std.ArrayList(u8).init(self.allocator);
        defer endpoint.deinit();

        try endpoint.appendSlice("/api/v1/orders?status=done");

        if (symbol) |s| {
            const market_symbol = try self.base.marketId(s);
            defer self.allocator.free(market_symbol);

            try endpoint.appendSlice("&symbol=");
            try endpoint.appendSlice(market_symbol);
        }

        if (since) |s| {
            const since_str = try std.fmt.allocPrint(self.allocator, "&startAt={d}", .{s});
            defer self.allocator.free(since_str);
            try endpoint.appendSlice(since_str);
        }

        const headers = try self.signRequest("GET", endpoint.items, null, null);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint.items });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, headers);
        defer self.allocator.free(response);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response);
        defer parsed.deinit();

        const root = parsed.value;
        const data_obj = root.object.get("data") orelse return error.InvalidResponse;
        const items_obj = data_obj.object.get("items") orelse return error.InvalidResponse;

        return try self.parseOrders(items_obj);
    }

    fn parseOrders(self: *KucoinExchange, data: std.json.Value) ![]Order {
        var result = std.ArrayList(Order).init(self.allocator);
        errdefer result.deinit();

        if (data == .array) {
            for (data.array.items) |order_obj| {
                const order = try self.parseOrder(order_obj);
                try result.append(order);
            }
        }

        return result.toOwnedSlice();
    }
};

// Factory functions
pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*KucoinExchange {
    return KucoinExchange.init(allocator, auth_config, false);
}

pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*KucoinExchange {
    return KucoinExchange.init(allocator, auth_config, true);
}
