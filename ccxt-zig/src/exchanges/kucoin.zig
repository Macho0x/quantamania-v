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

        const http_client = try http.HttpClient.init(allocator);
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
        defer self.allocator.free(response);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response);
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
                .info = market_data,
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
        const market_symbol = try self.base.marketId(symbol);
        defer self.allocator.free(market_symbol);

        const endpoint = try std.fmt.allocPrint(self.allocator, "/api/v1/market/stats?symbol={s}", .{market_symbol});
        defer self.allocator.free(endpoint);

        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer self.allocator.free(response);

        var parser = json.JsonParser.init(self.allocator);
        const parsed = try parser.parse(response);
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
            .datetime = try time.TimeUtils.iso8601(self.allocator, time.TimeUtils.now()),
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
            .info = obj,
        };
    }

    // Stub implementations for remaining methods
    pub fn fetchOrderBook(self: *KucoinExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        _ = self;
        _ = symbol;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchOHLCV(self: *KucoinExchange, symbol: []const u8, timeframe: []const u8, since: ?i64, limit: ?u32) ![]OHLCV {
        _ = self;
        _ = symbol;
        _ = timeframe;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchTrades(self: *KucoinExchange, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        _ = self;
        _ = symbol;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchBalance(self: *KucoinExchange) ![]Balance {
        _ = self;
        return error.NotImplemented;
    }

    pub fn createOrder(self: *KucoinExchange, symbol: []const u8, order_type: OrderType, side: OrderSide, amount: f64, price: ?f64, params: ?std.StringHashMap([]const u8)) !Order {
        _ = self;
        _ = symbol;
        _ = order_type;
        _ = side;
        _ = amount;
        _ = price;
        _ = params;
        return error.NotImplemented;
    }

    pub fn cancelOrder(self: *KucoinExchange, order_id: []const u8, symbol: ?[]const u8) !void {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchOrder(self: *KucoinExchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchOpenOrders(self: *KucoinExchange, symbol: ?[]const u8) ![]Order {
        _ = self;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchClosedOrders(self: *KucoinExchange, symbol: ?[]const u8, since: ?i64, limit: ?u32) ![]Order {
        _ = self;
        _ = symbol;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }
};

// Factory functions
pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*KucoinExchange {
    return KucoinExchange.init(allocator, auth_config, false);
}

pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*KucoinExchange {
    return KucoinExchange.init(allocator, auth_config, true);
}
