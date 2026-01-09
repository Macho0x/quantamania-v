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

// OKX Exchange Implementation
pub const OKXExchange = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    api_key: ?[]const u8,
    secret_key: ?[]const u8,
    passphrase: ?[]const u8,
    testnet: bool,

    // API endpoints
    const API_URL = "https://www.okx.com";
    const API_URL_TESTNET = "https://www.okx.com";
    const WS_URL = "wss://ws.okx.com:8443/ws/v5/public";
    const WS_URL_TESTNET = "wss://ws.okx.com:8443/ws/v5/public";

    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig, testnet: bool) !*OKXExchange {
        const self = try allocator.create(OKXExchange);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.api_key = auth_config.apiKey;
        self.secret_key = auth_config.apiSecret;
        self.passphrase = auth_config.passphrase;
        self.testnet = testnet;

        const http_client = try http.HttpClient.init(allocator);
        errdefer http_client.deinit();

        const name = try allocator.dupe(u8, "okx");
        const base_url = if (testnet) API_URL_TESTNET else API_URL;
        const base_url_copy = try allocator.dupe(u8, base_url);
        const ws_url = if (testnet) WS_URL_TESTNET else WS_URL;
        const ws_url_copy = try allocator.dupe(u8, ws_url);

        self.base = exchange.BaseExchange{
            .allocator = allocator,
            .name = name,
            .api_url = base_url_copy,
            .ws_url = ws_url_copy,
            .http_client = http_client,
            .auth_config = auth_config,
            .markets = null,
            .last_markets_fetch = 0,
            .rate_limit = 20, // Private: 20 requests/second
            .rate_limit_window_ms = 1000,
            .request_counter = 0,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .json_parser = json.JsonParser.init(allocator),
        };

        try self.base.headers.put(try allocator.dupe(u8, "User-Agent"), try allocator.dupe(u8, self.base.user_agent));
        try self.base.headers.put(try allocator.dupe(u8, "Accept"), try allocator.dupe(u8, "application/json"));

        return self;
    }

    pub fn deinit(self: *OKXExchange) void {
        if (self.api_key) |k| self.allocator.free(k);
        if (self.secret_key) |s| self.allocator.free(s);
        if (self.passphrase) |p| self.allocator.free(p);
        self.base.deinit();
        self.allocator.destroy(self);
    }

    // OKX-specific authentication
    fn authenticate(
        self: *OKXExchange,
        method: []const u8,
        endpoint: []const u8,
        body: ?[]const u8,
        headers: *std.StringHashMap([]const u8),
    ) !void {
        if (self.api_key) |key| {
            try headers.put(try self.allocator.dupe(u8, "OK-ACCESS-KEY"), try self.allocator.dupe(u8, key));
        }

        // ISO 8601 timestamp
        const timestamp = try time.TimeUtils.msToISO8601(self.allocator, time.TimeUtils.now());
        defer self.allocator.free(timestamp);

        try headers.put(try self.allocator.dupe(u8, "OK-ACCESS-TIMESTAMP"), try self.allocator.dupe(u8, timestamp));

        if (self.passphrase) |pass| {
            try headers.put(try self.allocator.dupe(u8, "OK-ACCESS-PASSPHRASE"), try self.allocator.dupe(u8, pass));
        }

        if (self.secret_key) |secret| {
            var message = std.ArrayList(u8).init(self.allocator);
            defer message.deinit();

            try message.appendSlice(timestamp);
            try message.appendSlice(method);
            try message.appendSlice(endpoint);

            if (body) |b| {
                try message.appendSlice(b);
            }

            const signature = try crypto.Signer.hmacSha256Base64(self.allocator, secret, message.items);
            defer self.allocator.free(signature);

            try headers.put(try self.allocator.dupe(u8, "OK-ACCESS-SIGN"), signature);
        }
    }

    // ==================== Market Data ====================

    pub fn fetchMarkets(self: *OKXExchange) ![]Market {
        if (self.base.isMarketsCacheValid()) {
            return self.base.markets.?;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/api/v5/public/instruments?instType=SPOT", .{self.base.api_url});
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        var markets = std.ArrayList(Market).init(self.allocator);
        defer markets.deinit();

        const data = parsed.value.get("data") orelse return error.InvalidResponse;

        switch (data) {
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

    fn parseMarket(self: *OKXExchange, json_val: std.json.Value) !Market {
        const parser = &self.base.json_parser;

        const id = parser.getString(json_val, "instId", "") orelse "";
        const base_asset = parser.getString(json_val, "baseCcy", "") orelse "";
        const quote_asset = parser.getString(json_val, "quoteCcy", "") orelse "";
        const symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base_asset, quote_asset });
        const base_copy = try self.allocator.dupe(u8, base_asset);
        const quote_copy = try self.allocator.dupe(u8, quote_asset);

        const state = parser.getString(json_val, "state", "") orelse "";
        const is_active = std.mem.eql(u8, state, "live");

        const tick_size = parser.getFloat(json_val.get("tickSz") orelse .{ .float = 0 }, 0);
        const lot_size = parser.getFloat(json_val.get("lotSz") orelse .{ .float = 0 }, 0);
        const min_order_size = parser.getFloat(json_val.get("minSz") orelse .{ .float = 0 }, 0);

        var limits = Market.MarketLimits{};
        var precision = Market.MarketPrecision{};

        if (tick_size > 0) {
            precision.price = @as(u8, @intFromFloat(-@log10(tick_size)));
        }

        if (lot_size > 0) {
            precision.amount = @as(u8, @intFromFloat(-@log10(lot_size)));
        }

        if (min_order_size > 0) {
            limits.amount = .{ .min = min_order_size, .max = null };
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
            .margin = parser.getString(json_val, "ctType", "") != null,
            .future = false,
            .swap = false,
            .option = false,
            .limits = limits,
            .precision = precision,
            .info = json_val,
        };
    }

    pub fn fetchTicker(self: *OKXExchange, symbol: []const u8) !Ticker {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/api/v5/market/ticker?instId={s}", .{ self.base.api_url, market.id });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const data = parsed.value.get("data") orelse return error.InvalidResponse;
        const ticker_data = if (data.array) |arr| arr.items[0] else json_val;

        return self.parseTicker(ticker_data, symbol);
    }

    fn parseTicker(self: *OKXExchange, json_val: std.json.Value, symbol: []const u8) !Ticker {
        const parser = &self.base.json_parser;

        return Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = self.base.parseTimestamp(json_val.get("ts"), time.TimeUtils.now()),
            .high = parser.getFloat(json_val.get("high24h") orelse .{ .float = 0 }, 0),
            .low = parser.getFloat(json_val.get("low24h") orelse .{ .float = 0 }, 0),
            .bid = parser.getFloat(json_val.get("bidPx") orelse .{ .float = 0 }, 0),
            .bidVolume = parser.getFloat(json_val.get("bidSz") orelse .{ .float = 0 }, 0),
            .ask = parser.getFloat(json_val.get("askPx") orelse .{ .float = 0 }, 0),
            .askVolume = parser.getFloat(json_val.get("askSz") orelse .{ .float = 0 }, 0),
            .last = parser.getFloat(json_val.get("lastPx") orelse .{ .float = 0 }, 0),
            .baseVolume = parser.getFloat(json_val.get("vol24h") orelse .{ .float = 0 }, 0),
            .quoteVolume = parser.getFloat(json_val.get("volCcy24h") orelse .{ .float = 0 }, 0),
            .info = json_val,
        };
    }

    pub fn fetchOrderBook(self: *OKXExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/api/v5/market/books?instId={s}&sz={d}",
            .{ self.base.api_url, market.id, limit orelse 20 });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const data = parsed.value.get("data") orelse return error.InvalidResponse;
        const book_data = if (data.array) |arr| arr.items[0] else json_val;

        return self.parseOrderBook(book_data, symbol);
    }

    fn parseOrderBook(self: *OKXExchange, json_val: std.json.Value, symbol: []const u8) !OrderBook {
        const parser = &self.base.json_parser;
        const timestamp = self.base.parseTimestamp(json_val.get("ts"), time.TimeUtils.now());

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
        self: *OKXExchange,
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
            "{s}/api/v5/market/candles?instId={s}&bar={s}",
            .{ self.base.api_url, market.id, timeframe }));

        if (since) |s| {
            try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
                "&after={d}", .{s}));
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

    fn parseOHLCV(self: *OKXExchange, json_val: std.json.Value, symbol: []const u8) ![]OHLCV {
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
                                    .open = parser.getFloat(candle.items[1], 0),
                                    .high = parser.getFloat(candle.items[2], 0),
                                    .low = parser.getFloat(candle.items[3], 0),
                                    .close = parser.getFloat(candle.items[4], 0),
                                    .volume = parser.getFloat(candle.items[5], 0),
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

    pub fn fetchTrades(self: *OKXExchange, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{s}/api/v5/market/trades?instId={s}", .{ self.base.api_url, market.id }));

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

    fn parseTrades(self: *OKXExchange, json_val: std.json.Value, symbol: []const u8) ![]Trade {
        const parser = &self.base.json_parser;

        var trades = std.ArrayList(Trade).init(self.allocator);
        defer trades.deinit();

        const data = json_val.get("data") orelse json_val;

        switch (data) {
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

    fn parseTrade(self: *OKXExchange, json_val: std.json.Value, symbol: []const u8) !Trade {
        const parser = &self.base.json_parser;

        const side_str = parser.getString(json_val, "side", "") orelse "";
        const is_buy = std.mem.eql(u8, side_str, "buy");

        return Trade{
            .id = parser.getString(json_val, "tradeId", "") orelse "",
            .timestamp = self.base.parseTimestamp(json_val.get("ts"), time.TimeUtils.now()),
            .datetime = try self.base.parseDatetime(self.allocator, self.base.parseTimestamp(json_val.get("ts"), time.TimeUtils.now())),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = .spot,
            .side = if (is_buy) "buy" else "sell",
            .price = parser.getFloat(json_val.get("px") orelse .{ .float = 0 }, 0),
            .amount = parser.getFloat(json_val.get("sz") orelse .{ .float = 0 }, 0),
            .cost = parser.getFloat(json_val.get("px") orelse .{ .float = 0 }, 0) *
                parser.getFloat(json_val.get("sz") orelse .{ .float = 0 }, 0),
            .info = json_val,
        };
    }

    // ==================== Private Methods ====================

    pub fn fetchBalance(self: *OKXExchange) !Balance {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/api/v5/account/balance", .{self.base.api_url});
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

        try self.authenticate("GET", "/api/v5/account/balance", null, &headers);

        const response = try self.base.http_client.get(url, headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        var total_free: f64 = 0;
        var total_used: f64 = 0;

        const data = parsed.value.get("data") orelse return error.InvalidResponse;

        switch (data) {
            .array => |arr| {
                if (arr.items.len > 0) {
                    const details = arr.items[0].get("details") orelse .{ .array = .{} };
                    switch (details) {
                        .array => |details_arr| {
                            for (details_arr.items) |detail| {
                                const currency = parser.getString(detail, "ccy", "") orelse "";
                                if (std.mem.eql(u8, currency, "USDT")) {
                                    const avail = parser.getFloat(detail.get("availBal") orelse .{ .float = 0 }, 0);
                                    const frozen = parser.getFloat(detail.get("frozenBal") orelse .{ .float = 0 }, 0);
                                    total_free = avail;
                                    total_used = frozen;
                                    break;
                                }
                            }
                        },
                        else => {},
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
        self: *OKXExchange,
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
            "{{\"instId\":\"{s}\",\"side\":\"{s}\",\"ordType\":\"{s}\",\"sz\":\"{d}\"",
            .{ market.id, side_str, type_str, amount }));

        if (price) |p| {
            try body.appendSlice(try std.fmt.allocPrint(self.allocator,
                ",\"px\":\"{d}\"", .{p}));
        }

        try body.appendSlice("}}");

        const endpoint = "/api/v5/trade/order";
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

        const data = parsed.value.get("data") orelse return error.InvalidResponse;
        const order_id = parser.getString(data, "ordId", "") orelse "";

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

// Factory functions
pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*OKXExchange {
    return OKXExchange.init(allocator, auth_config, false);
}

pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*OKXExchange {
    return OKXExchange.init(allocator, auth_config, true);
}
