const std = @import("std");
const exchange = @import("../base/exchange.zig");
const auth = @import("../base/auth.zig");
const http = @import("../base/http.zig");
const json = @import("../utils/json.zig");
const time = @import("../utils/time.zig");
const crypto = @import("../utils/crypto.zig");
const precision_utils = @import("../utils/precision.zig");
const errors = @import("../base/errors.zig");

// Import models
const Market = @import("../models/market.zig").Market;
const MarketPrecision = @import("../models/market.zig").MarketPrecision;
const Ticker = @import("../models/ticker.zig").Ticker;
const OrderBook = @import("../models/orderbook.zig").OrderBook;
const Order = @import("../models/order.zig").Order;
const OrderType = @import("../models/order.zig").OrderType;
const OrderSide = @import("../models/order.zig").OrderSide;
const Balance = @import("../models/balance.zig").Balance;
const Trade = @import("../models/trade.zig").Trade;
const OHLCV = @import("../models/ohlcv.zig").OHLCV;

// Bitfinex Exchange Implementation
// Precision mode: significant_digits
// Exchange-specific tags: Implement based on Bitfinex API documentation
pub const BitfinexExchange = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    api_key: ?[]const u8,
    secret_key: ?[]const u8,
    testnet: bool,
    precision_config: precision_utils.ExchangePrecisionConfig,

    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig, testnet: bool) !*BitfinexExchange {
        const self = try allocator.create(BitfinexExchange);
        self.allocator = allocator;
        self.api_key = auth_config.apiKey;
        self.secret_key = auth_config.apiSecret;
        self.testnet = testnet;
        
        // Bitfinex uses significant_digits precision mode (unique among exchanges)
        self.precision_config = .{
            .amount_mode = .significant_digits,
            .price_mode = .significant_digits,
            .default_amount_precision = 8,
            .default_price_precision = 8,
            .supports_tick_size = false,
        };

        var http_client = try http.HttpClient.init(allocator);
        const base_name = try allocator.dupe(u8, "bitfinex");
        const base_url = try allocator.dupe(u8, if (testnet) "https://test.bitfinex.com" else "https://api-pub.bitfinex.com");
        const ws_url = try allocator.dupe(u8, if (testnet) "wss://test.bitfinex.com/ws/2" else "wss://api-pub.bitfinex.com/ws/2");

        self.base = exchange.BaseExchange{
            .allocator = allocator,
            .name = base_name,
            .api_url = base_url,
            .ws_url = ws_url,
            .http_client = http_client,
            .auth_config = auth_config,
            .markets = null,
            .last_markets_fetch = 0,
            .rate_limit = 1000,
            .rate_limit_window_ms = 60000,
            .request_counter = 0,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .json_parser = json.JsonParser.init(allocator),
        };

        try self.base.headers.put(try allocator.dupe(u8, "User-Agent"), try allocator.dupe(u8, self.base.user_agent));
        try self.base.headers.put(try allocator.dupe(u8, "Accept"), try allocator.dupe(u8, "application/json"));

        return self;
    }

    pub fn deinit(self: *BitfinexExchange) void {
        if (self.api_key) |k| self.allocator.free(k);
        if (self.secret_key) |s| self.allocator.free(s);
        self.base.deinit();
        self.allocator.destroy(self);
    }

    // Template exchange - methods return error.NotImplemented
    // Full API implementation pending future development
    // Bitfinex uses significant_digits precision mode (unique among exchanges)
    pub fn fetchMarkets(self: *BitfinexExchange) ![]Market {
        _ = self;
        return error.NotImplemented;
    }

    pub fn fetchTicker(self: *BitfinexExchange, symbol: []const u8) !Ticker {
        _ = self;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchOrderBook(self: *BitfinexExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        _ = self;
        _ = symbol;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchOHLCV(self: *BitfinexExchange, symbol: []const u8, timeframe: []const u8, since: ?i64, limit: ?u32) ![]OHLCV {
        _ = self;
        _ = symbol;
        _ = timeframe;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchTrades(self: *BitfinexExchange, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        _ = self;
        _ = symbol;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchBalance(self: *BitfinexExchange) ![]Balance {
        _ = self;
        return error.NotImplemented;
    }

    pub fn createOrder(self: *BitfinexExchange, symbol: []const u8, order_type: OrderType, side: OrderSide, amount: f64, price: ?f64, params: ?std.StringHashMap([]const u8)) !Order {
        _ = params;
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        const market = self.base.findMarket(symbol) orelse return error.SymbolNotFound;

        // Apply Bitfinex's significant_digits precision handling
        const precision_amount = precision_utils.PrecisionUtils.roundToSignificantDigits(amount, self.precision_config.default_amount_precision);
        const precision_price = if (price) |p| precision_utils.PrecisionUtils.roundToSignificantDigits(p, self.precision_config.default_price_precision) else null;

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        try body.appendSlice(try std.fmt.allocPrint(self.allocator,
            "symbol={s}&amount={d}&side={s}&type={s}",
            .{ market.id, precision_amount, side, order_type }));

        if (price) |p| {
            try body.appendSlice(try std.fmt.allocPrint(self.allocator, "&price={d}", .{ precision_price }));
        }

        const url = "https://api.bitfinex.com/v2/auth/w/order/submit";

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();

        try self.authenticate(&headers, "/v2/auth/w/order/submit", body.items);

        const response = try self.base.http_client.post(url, &headers, body.items);
        defer response.deinit(self.allocator);

        if (response.status != 200) {
            return error.NetworkError;
        }

        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();

        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        const order_id = parsed.array.items[0].number.asInt();

        return Order{
            .id = try std.fmt.allocPrint(self.allocator, "{d}", .{order_id}),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = try self.allocator.dupe(u8, order_type),
            .side = try self.allocator.dupe(u8, side),
            .price = precision_price,
            .amount = precision_amount,
            .status = try self.allocator.dupe(u8, "open"),
            .timestamp = std.time.milliTimestamp(),
            .info = parsed,
        };
    }

    pub fn cancelOrder(self: *BitfinexExchange, order_id: []const u8, symbol: ?[]const u8) !void {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        try body.appendSlice(try std.fmt.allocPrint(self.allocator, "id={s}", .{ order_id }));

        const url = "https://api.bitfinex.com/v2/auth/w/order/cancel";

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();

        try self.authenticate(&headers, "/v2/auth/w/order/cancel", body.items);

        const response = try self.base.http_client.post(url, &headers, body.items);
        defer response.deinit(self.allocator);

        if (response.status != 200) {
            return error.NetworkError;
        }
    }

    pub fn fetchOrder(self: *BitfinexExchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        const url = "https://api.bitfinex.com/v2/auth/r/order/{s}/status";

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();

        try self.authenticate(&headers, "/v2/auth/r/order/{s}/status", .{ order_id });

        const response = try self.base.http_client.get(url, &headers);
        defer response.deinit(self.allocator);

        if (response.status != 200) {
            return error.NetworkError;
        }

        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();

        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        const status = parsed.array.items[0].string orelse return error.NetworkError;
        const type_str = parsed.array.items[1].string orelse return error.NetworkError;
        const side_str = parsed.array.items[2].string orelse return error.NetworkError;
        const price = parsed.array.items[3].number.asFloat();
        const amount = parsed.array.items[4].number.asFloat();

        return Order{
            .id = try self.allocator.dupe(u8, order_id),
            .symbol = if (symbol) |s| try self.allocator.dupe(u8, s) else null,
            .type = try self.allocator.dupe(u8, type_str),
            .side = try self.allocator.dupe(u8, side_str),
            .price = price,
            .amount = amount,
            .status = try self.allocator.dupe(u8, status),
            .timestamp = std.time.milliTimestamp(),
            .info = parsed,
        };
    }

    pub fn fetchOpenOrders(self: *BitfinexExchange, symbol: ?[]const u8) ![]Order {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        var url = "https://api.bitfinex.com/v2/auth/r/orders";
        if (symbol) |s| {
            const market = self.base.findMarket(s) orelse return error.SymbolNotFound;
            url = try std.fmt.allocPrint(self.allocator, "https://api.bitfinex.com/v2/auth/r/orders?symbol={s}", .{ market.id });
            defer self.allocator.free(url);
        }

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();

        try self.authenticate(&headers, "/v2/auth/r/orders", "");

        const response = try self.base.http_client.get(url, &headers);
        defer response.deinit(self.allocator);

        if (response.status != 200) {
            return error.NetworkError;
        }

        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();

        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        var orders = std.ArrayList(Order).init(self.allocator);

        for (parsed.array.items) |order_data| {
            const order_id = order_data.array.items[0].number.asInt();
            const status = order_data.array.items[1].string orelse continue;
            const type_str = order_data.array.items[2].string orelse continue;
            const side_str = order_data.array.items[3].string orelse continue;
            const price = order_data.array.items[4].number.asFloat();
            const amount = order_data.array.items[5].number.asFloat();
            const order_symbol = order_data.array.items[6].string orelse continue;

            try orders.append(Order{
                .id = try std.fmt.allocPrint(self.allocator, "{d}", .{order_id}),
                .symbol = try self.allocator.dupe(u8, order_symbol),
                .type = try self.allocator.dupe(u8, type_str),
                .side = try self.allocator.dupe(u8, side_str),
                .price = price,
                .amount = amount,
                .status = try self.allocator.dupe(u8, status),
                .timestamp = std.time.milliTimestamp(),
                .info = order_data,
            });
        }

        return orders.toOwnedSlice();
    }

    pub fn fetchClosedOrders(self: *BitfinexExchange, symbol: ?[]const u8, since: ?i64, limit: ?u32) ![]Order {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        var query = std.ArrayList(u8).init(self.allocator);
        defer query.deinit();

        if (symbol) |s| {
            const market = self.base.findMarket(s) orelse return error.SymbolNotFound;
            try query.appendSlice(try std.fmt.allocPrint(self.allocator, "symbol={s}", .{ market.id }));
        }

        if (since) |s| {
            if (query.len > 0) try query.append('&');
            try query.appendSlice(try std.fmt.allocPrint(self.allocator, "start={d}", .{ s }));
        }

        if (limit) |l| {
            if (query.len > 0) try query.append('&');
            try query.appendSlice(try std.fmt.allocPrint(self.allocator, "limit={d}", .{ l }));
        }

        var url = "https://api.bitfinex.com/v2/auth/r/orders/hist";
        if (query.len > 0) {
            url = try std.fmt.allocPrint(self.allocator, "https://api.bitfinex.com/v2/auth/r/orders/hist?{s}", .{ query.items });
            defer self.allocator.free(url);
        }

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();

        try self.authenticate(&headers, "/v2/auth/r/orders/hist", query.items);

        const response = try self.base.http_client.get(url, &headers);
        defer response.deinit(self.allocator);

        if (response.status != 200) {
            return error.NetworkError;
        }

        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();

        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        var orders = std.ArrayList(Order).init(self.allocator);

        for (parsed.array.items) |order_data| {
            const order_id = order_data.array.items[0].number.asInt();
            const status = order_data.array.items[1].string orelse continue;
            const type_str = order_data.array.items[2].string orelse continue;
            const side_str = order_data.array.items[3].string orelse continue;
            const price = order_data.array.items[4].number.asFloat();
            const amount = order_data.array.items[5].number.asFloat();
            const order_symbol = order_data.array.items[6].string orelse continue;

            try orders.append(Order{
                .id = try std.fmt.allocPrint(self.allocator, "{d}", .{order_id}),
                .symbol = try self.allocator.dupe(u8, order_symbol),
                .type = try self.allocator.dupe(u8, type_str),
                .side = try self.allocator.dupe(u8, side_str),
                .price = price,
                .amount = amount,
                .status = try self.allocator.dupe(u8, status),
                .timestamp = std.time.milliTimestamp(),
                .info = order_data,
            });
        }

        return orders.toOwnedSlice();
    }
};

pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*BitfinexExchange {
    return BitfinexExchange.init(allocator, auth_config, false);
}

pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*BitfinexExchange {
    return BitfinexExchange.init(allocator, auth_config, true);
}
