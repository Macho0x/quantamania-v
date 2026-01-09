const std = @import("std");
const exchange = @import("../base/exchange.zig");
const auth = @import("../base/auth.zig");
const http = @import("../base/http.zig");
const json = @import("../utils/json.zig");
const time = @import("../utils/time.zig");
const crypto = @import("../utils/crypto.zig");

// Import models
const Market = @import("../models/market.zig").Market;
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

// Gate.io Exchange Implementation
pub const GateIOExchange = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    api_key: ?[]const u8,
    secret_key: ?[]const u8,

    // API endpoints
    const API_URL = "https://api.gateio.ws/api/v4";
    const WS_URL = "wss://ws.gateio.ws/v4/ws";

    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*GateIOExchange {
        const self = try allocator.create(GateIOExchange);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.api_key = auth_config.apiKey;
        self.secret_key = auth_config.apiSecret;

        const http_client = try http.HttpClient.init(allocator);
        errdefer http_client.deinit();

        const name = try allocator.dupe(u8, "gate");
        const url = try allocator.dupe(u8, API_URL);
        const ws_url = try allocator.dupe(u8, WS_URL);

        self.base = exchange.BaseExchange{
            .allocator = allocator,
            .name = name,
            .api_url = url,
            .ws_url = ws_url,
            .http_client = http_client,
            .auth_config = auth_config,
            .markets = null,
            .last_markets_fetch = 0,
            .rate_limit = 50, // Private: 50 requests/second
            .rate_limit_window_ms = 1000,
            .request_counter = 0,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .json_parser = json.JsonParser.init(allocator),
        };

        try self.base.headers.put(try allocator.dupe(u8, "User-Agent"), try allocator.dupe(u8, self.base.user_agent));
        try self.base.headers.put(try allocator.dupe(u8, "Accept"), try allocator.dupe(u8, "application/json"));

        return self;
    }

    pub fn deinit(self: *GateIOExchange) void {
        if (self.api_key) |k| self.allocator.free(k);
        if (self.secret_key) |s| self.allocator.free(s);
        self.base.deinit();
        self.allocator.destroy(self);
    }

    // Gate.io-specific authentication
    fn authenticate(
        self: *GateIOExchange,
        method: []const u8,
        endpoint: []const u8,
        body: ?[]const u8,
        headers: *std.StringHashMap([]const u8),
    ) !void {
        if (self.api_key) |key| {
            try headers.put(try self.allocator.dupe(u8, "Authorization"), try self.allocator.dupe(u8, key));
        }

        const timestamp = try std.fmt.allocPrint(self.allocator, "{d}", .{time.TimeUtils.now() / 1000});
        defer self.allocator.free(timestamp);

        try headers.put(try self.allocator.dupe(u8, "Timestamp"), try self.allocator.dupe(u8, timestamp));

        if (self.secret_key) |secret| {
            var payload = std.ArrayList(u8).init(self.allocator);
            defer payload.deinit();

            try payload.appendSlice(method);
            try payload.appendSlice(endpoint);

            if (body) |b| {
                try payload.appendSlice(b);
            }

            try payload.appendSlice(timestamp);

            const signature = try crypto.Signer.hmacSha256Hex(secret, payload.items);
            try headers.put(try self.allocator.dupe(u8, "Sign"), try self.allocator.dupe(u8, &signature));
        }
    }

    // ==================== Market Data ====================

    pub fn fetchMarkets(self: *GateIOExchange) ![]Market {
        if (self.base.isMarketsCacheValid()) {
            return self.base.markets.?;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/spot/currency_pairs", .{self.base.api_url});
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        var markets = std.ArrayList(Market).init(self.allocator);
        defer markets.deinit();

        switch (parsed.value) {
            .array => |arr| {
                for (arr.items) |item| {
                    const market = try self.parseMarket(item);
                    try markets.append(market);
                }
            },
            else => return error.InvalidResponse,
        }

        self.base.last_markets_fetch = time.TimeUtils.now();
        const markets_copy = try markets.toOwnedSlice();
        self.base.markets = markets_copy;

        return markets_copy;
    }

    fn parseMarket(self: *GateIOExchange, json_val: std.json.Value) !Market {
        const parser = &self.base.json_parser;

        const id = parser.getString(json_val, "id", "") orelse "";
        const base_asset = parser.getString(json_val, "base", "") orelse "";
        const quote_asset = parser.getString(json_val, "quote", "") orelse "";
        const symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base_asset, quote_asset });
        const base_copy = try self.allocator.dupe(u8, base_asset);
        const quote_copy = try self.allocator.dupe(u8, quote_asset);

        const trade_status = parser.getString(json_val, "trade_status", "") orelse "";
        const is_active = std.mem.eql(u8, trade_status, "tradable");

        const base_precision = parser.getInt(json_val.get("base_precision") orelse .{ .integer = 8 }, 8);
        const quote_precision = parser.getInt(json_val.get("quote_precision") orelse .{ .integer = 8 }, 8);
        const min_amount = parser.getFloat(json_val.get("min_base_amount") orelse .{ .float = 0 }, 0);

        var limits = Market.MarketLimits{};
        var precision = Market.MarketPrecision{};

        precision.base = @as(u8, @intCast(base_precision));
        precision.quote = @as(u8, @intCast(quote_precision));

        if (min_amount > 0) {
            limits.amount = .{ .min = min_amount, .max = null };
        }

        return Market{
            .id = try self.allocator.dupe(u8, id),
            .symbol = symbol,
            .base = base_copy,
            .quote = quote_copy,
            .baseId = try self.allocator.dupe(u8, base_asset),
            .quoteId = try self.allocator.dupe(u8, quote_asset),
            .active = is_active,
            .spot = true,
            .margin = false,
            .future = false,
            .swap = false,
            .option = false,
            .limits = limits,
            .precision = precision,
            .info = json_val,
        };
    }

    pub fn fetchTicker(self: *GateIOExchange, symbol: []const u8) !Ticker {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/spot/tickers?currency_pair={s}", .{ self.base.api_url, market.id });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const data = parsed.value.get("data") orelse return error.InvalidResponse;
        const ticker_data = if (data.array) |arr| arr.items[0] else json_val;

        return self.parseTicker(ticker_data, symbol);
    }

    fn parseTicker(self: *GateIOExchange, json_val: std.json.Value, symbol: []const u8) !Ticker {
        const parser = &self.base.json_parser;

        return Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = self.base.parseTimestamp(json_val.get("timestamp"), time.TimeUtils.now()),
            .high = parser.getFloat(json_val.get("high_24h") orelse .{ .float = 0 }, 0),
            .low = parser.getFloat(json_val.get("low_24h") orelse .{ .float = 0 }, 0),
            .bid = parser.getFloat(json_val.get("highest_bid") orelse .{ .float = 0 }, 0),
            .ask = parser.getFloat(json_val.get("lowest_ask") orelse .{ .float = 0 }, 0),
            .last = parser.getFloat(json_val.get("last") orelse .{ .float = 0 }, 0),
            .baseVolume = parser.getFloat(json_val.get("base_volume") orelse .{ .float = 0 }, 0),
            .quoteVolume = parser.getFloat(json_val.get("quote_volume") orelse .{ .float = 0 }, 0),
            .info = json_val,
        };
    }

    pub fn fetchOrderBook(self: *GateIOExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/spot/order_book?currency_pair={s}&limit={d}",
            .{ self.base.api_url, market.id, limit orelse 10 });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        return self.parseOrderBook(parsed.value, symbol);
    }

    fn parseOrderBook(self: *GateIOExchange, json_val: std.json.Value, symbol: []const u8) !OrderBook {
        const parser = &self.base.json_parser;
        const timestamp = self.base.parseTimestamp(json_val.get("timestamp"), time.TimeUtils.now());

        const bids_json = json_val.get("bids") orelse .{ .array = .{} };
        var bids = std.ArrayList(OrderBook.OrderBookEntry).init(self.allocator);
        defer bids.deinit();

        switch (bids_json) {
            .array => |arr| {
                for (arr.items) |item| {
                    switch (item) {
                        .array => |b| {
                            if (b.items.len >= 2) {
                                const entry = OrderBook.OrderBookEntry{
                                    .price = parser.getFloat(b.items[0], 0),
                                    .amount = parser.getFloat(b.items[1], 0),
                                    .timestamp = timestamp,
                                };
                                try bids.append(entry);
                            }
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }

        const asks_json = json_val.get("asks") orelse .{ .array = .{} };
        var asks = std.ArrayList(OrderBook.OrderBookEntry).init(self.allocator);
        defer asks.deinit();

        switch (asks_json) {
            .array => |arr| {
                for (arr.items) |item| {
                    switch (item) {
                        .array => |a| {
                            if (a.items.len >= 2) {
                                const entry = OrderBook.OrderBookEntry{
                                    .price = parser.getFloat(a.items[0], 0),
                                    .amount = parser.getFloat(a.items[1], 0),
                                    .timestamp = timestamp,
                                };
                                try asks.append(entry);
                            }
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }

        const datetime = try self.base.parseDatetime(self.allocator, timestamp);

        return OrderBook{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = timestamp,
            .datetime = datetime,
            .bids = try bids.toOwnedSlice(),
            .asks = try asks.toOwnedSlice(),
            .info = json_val,
        };
    }

    pub fn fetchOHLCV(
        self: *GateIOExchange,
        symbol: []const u8,
        timeframe: []const u8,
        since: ?i64,
        limit: ?u32,
    ) ![]OHLCV {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{s}/spot/candlesticks?currency_pair={s}&interval={s}",
            .{ self.base.api_url, market.id, timeframe }));

        if (since) |s| {
            try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
                "&start={d}", .{s}));
        }

        if (limit) |l| {
            try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
                "&limit={d}", .{l}));
        }

        const url = try self.allocator.dupe(u8, url_buf.items);
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        return try self.parseOHLCV(parsed.value, symbol);
    }

    fn parseOHLCV(self: *GateIOExchange, json_val: std.json.Value, symbol: []const u8) ![]OHLCV {
        const parser = &self.base.json_parser;

        var ohlcvs = std.ArrayList(OHLCV).init(self.allocator);
        defer ohlcvs.deinit();

        const data = json_val.get("data") orelse json_val;

        switch (data) {
            .array => |arr| {
                for (arr.items) |item| {
                    switch (item) {
                        .array => |candle| {
                            if (candle.items.len >= 6) {
                                const ohlcv = OHLCV{
                                    .timestamp = parser.getInt(candle.items[0], 0),
                                    .open = parser.getFloat(candle.items[5], 0),
                                    .high = parser.getFloat(candle.items[3], 0),
                                    .low = parser.getFloat(candle.items[4], 0),
                                    .close = parser.getFloat(candle.items[2], 0),
                                    .volume = parser.getFloat(candle.items[1], 0),
                                };
                                try ohlcvs.append(ohlcv);
                            }
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }

        return try ohlcvs.toOwnedSlice();
    }

    pub fn fetchTrades(self: *GateIOExchange, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{s}/spot/trades?currency_pair={s}", .{ self.base.api_url, market.id }));

        if (limit) |l| {
            try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator, "&limit={d}", .{l}));
        }

        const url = try self.allocator.dupe(u8, url_buf.items);
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        return try self.parseTrades(parsed.value, symbol);
    }

    fn parseTrades(self: *GateIOExchange, json_val: std.json.Value, symbol: []const u8) ![]Trade {
        const parser = &self.base.json_parser;

        var trades = std.ArrayList(Trade).init(self.allocator);
        defer trades.deinit();

        switch (json_val) {
            .array => |arr| {
                for (arr.items) |item| {
                    const trade = try self.parseTrade(item, symbol);
                    try trades.append(trade);
                }
            },
            else => {},
        }

        return try trades.toOwnedSlice();
    }

    fn parseTrade(self: *GateIOExchange, json_val: std.json.Value, symbol: []const u8) !Trade {
        const parser = &self.base.json_parser;

        const side_str = parser.getString(json_val, "side", "") orelse "";
        const is_buy = std.mem.eql(u8, side_str, "buy");

        return Trade{
            .id = parser.getString(json_val, "id", "") orelse "",
            .timestamp = self.base.parseTimestamp(json_val.get("create_time_ms"), time.TimeUtils.now()),
            .datetime = try self.base.parseDatetime(self.allocator, self.base.parseTimestamp(json_val.get("create_time_ms"), time.TimeUtils.now())),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = .spot,
            .side = if (is_buy) "buy" else "sell",
            .price = parser.getFloat(json_val.get("price") orelse .{ .float = 0 }, 0),
            .amount = parser.getFloat(json_val.get("amount") orelse .{ .float = 0 }, 0),
            .cost = parser.getFloat(json_val.get("price") orelse .{ .float = 0 }, 0) *
                parser.getFloat(json_val.get("amount") orelse .{ .float = 0 }, 0),
            .info = json_val,
        };
    }

    // ==================== Private Methods ====================

    pub fn fetchBalance(self: *GateIOExchange) !Balance {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/wallet/balances", .{self.base.api_url});
        defer self.allocator.free(url);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        try self.authenticate("GET", "/wallet/balances", null, &headers);

        const response = try self.base.http_client.get(url, headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        var total_free: f64 = 0;
        var total_used: f64 = 0;

        const data = parsed.value.get("data") orelse return error.InvalidResponse;

        switch (data) {
            .array => |arr| {
                for (arr.items) |account| {
                    const currency = parser.getString(account, "currency", "") orelse "";
                    if (std.mem.eql(u8, currency, "USDT")) {
                        const available = parser.getFloat(account.get("available") orelse .{ .float = 0 }, 0);
                        const locked = parser.getFloat(account.get("locked") orelse .{ .float = 0 }, 0);
                        total_free = available;
                        total_used = locked;
                        break;
                    }
                }
            },
            else => {},
        }

        return Balance{
            .free = types.Decimal{ .value = @as(i128, @intFromFloat(total_free * 100_000_000)), .scale = 8 },
            .used = types.Decimal{ .value = @as(i128, @intFromFloat(total_used * 100_000_000)), .scale = 8 },
            .total = types.Decimal{ .value = @as(i128, @intFromFloat((total_free + total_used) * 100_000_000)), .scale = 8 },
            .currency = "USDT",
            .timestamp = time.TimeUtils.now(),
            .info = parsed.value,
        };
    }

    pub fn createOrder(
        self: *GateIOExchange,
        symbol: []const u8,
        type_str: []const u8,
        side_str: []const u8,
        amount: f64,
        price: ?f64,
        params: ?std.StringHashMap([]const u8),
    ) !Order {
        _ = params;
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        try body.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{{\"currency_pair\":\"{s}\",\"side\":\"{s}\",\"type\":\"{s}\",\"amount\":\"{d}\"",
            .{ market.id, side_str, type_str, amount }));

        if (price) |p| {
            try body.appendSlice(try std.fmt.allocPrint(self.allocator,
                ",\"price\":\"{d}\"", .{p}));
        }

        try body.appendSlice("}}");

        const endpoint = "/spot/orders";
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base.api_url, endpoint });
        defer self.allocator.free(url);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        try self.authenticate("POST", endpoint, body.items, &headers);

        const response = try self.base.http_client.post(url, headers, body.items);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const order_id = parser.getString(parsed.value, "id", "") orelse "";

        return Order{
            .id = try self.allocator.dupe(u8, order_id),
            .timestamp = time.TimeUtils.now(),
            .datetime = try self.base.parseDatetime(self.allocator, time.TimeUtils.now()),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = OrderType.limit,
            .side = if (std.mem.eql(u8, side_str, "buy")) .buy else .sell,
            .price = price orelse 0,
            .amount = amount,
            .filled = 0,
            .remaining = amount,
            .status = .open,
            .info = parsed.value,
        };
    }
};

// Factory function
pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*GateIOExchange {
    return GateIOExchange.init(allocator, auth_config);
}
