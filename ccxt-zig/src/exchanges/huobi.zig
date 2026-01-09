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

// Huobi Exchange Implementation
pub const HuobiExchange = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    api_key: ?[]const u8,
    secret_key: ?[]const u8,
    account_id: ?[]const u8,

    // API endpoints
    const API_URL = "https://api.huobi.com";
    const API_URL_CN = "https://api.huobi.pro";
    const WS_URL = "wss://api.huobi.pro/ws/v2";
    const WS_URL_CN = "wss://api.huobi.com/ws/v2";

    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig, use_cn: bool) !*HuobiExchange {
        const self = try allocator.create(HuobiExchange);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.api_key = auth_config.apiKey;
        self.secret_key = auth_config.apiSecret;
        self.account_id = null;

        const http_client = try http.HttpClient.init(allocator);
        errdefer http_client.deinit();

        const name = try allocator.dupe(u8, "huobi");
        const base_url = if (use_cn) API_URL_CN else API_URL;
        const base_url_copy = try allocator.dupe(u8, base_url);
        const ws_url = if (use_cn) WS_URL_CN else WS_URL;
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
            .rate_limit = 10, // 10 requests/second default
            .rate_limit_window_ms = 1000,
            .request_counter = 0,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .json_parser = json.JsonParser.init(allocator),
        };

        try self.base.headers.put(try allocator.dupe(u8, "User-Agent"), try allocator.dupe(u8, self.base.user_agent));
        try self.base.headers.put(try allocator.dupe(u8, "Accept"), try allocator.dupe(u8, "application/json"));

        return self;
    }

    pub fn deinit(self: *HuobiExchange) void {
        if (self.api_key) |k| self.allocator.free(k);
        if (self.secret_key) |s| self.allocator.free(s);
        if (self.account_id) |a| self.allocator.free(a);
        self.base.deinit();
        self.allocator.destroy(self);
    }

    // Huobi-specific authentication
    fn authenticate(
        self: *HuobiExchange,
        method: []const u8,
        endpoint: []const u8,
        params: std.StringHashMap([]const u8),
        body: ?[]const u8,
        headers: *std.StringHashMap([]const u8),
    ) !void {
        if (self.api_key) |key| {
            try headers.put(try self.allocator.dupe(u8, "AccessKeyId"), try self.allocator.dupe(u8, key));
        }

        const timestamp = try time.TimeUtils.msToISO8601(self.allocator, time.TimeUtils.now());
        defer self.allocator.free(timestamp);

        try headers.put(try self.allocator.dupe(u8, "SignatureVersion"), try self.allocator.dupe(u8, "2"));
        try headers.put(try self.allocator.dupe(u8, "Timestamp"), try self.allocator.dupe(u8, timestamp));
        try headers.put(try self.allocator.dupe(u8, "Request-id"), try self.allocator.dupe(u8, "0"));

        if (self.secret_key) |secret| {
            // Build query string from params
            var query_parts = std.ArrayList([]const u8).init(self.allocator);
            defer query_parts.deinit();

            var iter = params.iterator();
            while (iter.next()) |entry| {
                try query_parts.append(try std.fmt.allocPrint(self.allocator, "{s}={s}", .{ entry.key_ptr.*, entry.value_ptr.* }));
            }

            // Sort and join params
            const query_string = try std.mem.join(self.allocator, "&", query_parts.items);

            // Build signature string
            var signature_msg = std.ArrayList(u8).init(self.allocator);
            defer signature_msg.deinit();

            try signature_msg.appendSlice(method);
            try signature_msg.appendSlice("\n");
            try signature_msg.appendSlice("api.huobi.pro");
            try signature_msg.appendSlice("\n");
            try signature_msg.appendSlice(endpoint);
            try signature_msg.appendSlice("\n");
            try signature_msg.appendSlice(query_string);

            const signature = try crypto.Signer.hmacSha256Hex(secret, signature_msg.items);
            try headers.put(try self.allocator.dupe(u8, "Signature"), try self.allocator.dupe(u8, &signature));
        }
    }

    // ==================== Market Data ====================

    pub fn fetchMarkets(self: *HuobiExchange) ![]Market {
        if (self.base.isMarketsCacheValid()) {
            return self.base.markets.?;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/v1/common/symbols", .{self.base.api_url});
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

    fn parseMarket(self: *HuobiExchange, json_val: std.json.Value) !Market {
        const parser = &self.base.json_parser;

        const id = parser.getString(json_val, "symbol", "") orelse "";
        const base_asset = parser.getString(json_val, "base-currency", "") orelse "";
        const quote_asset = parser.getString(json_val, "quote-currency", "") orelse "";
        const symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base_asset, quote_asset });
        const base_copy = try self.allocator.dupe(u8, base_asset);
        const quote_copy = try self.allocator.dupe(u8, quote_asset);

        const state = parser.getString(json_val, "state", "") orelse "";
        const is_active = std.mem.eql(u8, state, "online");

        const amount_precision = parser.getInt(json_val.get("amount-precision") orelse .{ .integer = 8 }, 8);
        const price_precision = parser.getInt(json_val.get("price-precision") orelse .{ .integer = 8 }, 8);
        const min_amount = parser.getFloat(json_val.get("min-order-amt") orelse .{ .float = 0 }, 0);
        const min_price = parser.getFloat(json_val.get("min-order-price") orelse .{ .float = 0 }, 0);

        var limits = Market.MarketLimits{};
        var precision = Market.MarketPrecision{};

        if (amount_precision > 0) {
            precision.amount = @as(u8, @intCast(amount_precision));
        }
        if (price_precision > 0) {
            precision.price = @as(u8, @intCast(price_precision));
        }

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

    pub fn fetchTicker(self: *HuobiExchange, symbol: []const u8) !Ticker {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/market/detail/merged?symbol={s}", .{ self.base.api_url, market.id });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const tick = parsed.value.get("tick") orelse return error.InvalidResponse;

        return self.parseTicker(tick, symbol);
    }

    fn parseTicker(self: *HuobiExchange, json_val: std.json.Value, symbol: []const u8) !Ticker {
        const parser = &self.base.json_parser;

        const bid_json = json_val.get("bid") orelse .{ .array = .{} };
        const ask_json = json_val.get("ask") orelse .{ .array = .{} };

        var bid_price: f64 = 0;
        var bid_amount: f64 = 0;
        var ask_price: f64 = 0;
        var ask_amount: f64 = 0;

        switch (bid_json) {
            .array => |arr| {
                if (arr.items.len >= 2) {
                    bid_price = parser.getFloat(arr.items[0], 0);
                    bid_amount = parser.getFloat(arr.items[1], 0);
                }
            },
            else => {},
        }

        switch (ask_json) {
            .array => |arr| {
                if (arr.items.len >= 2) {
                    ask_price = parser.getFloat(arr.items[0], 0);
                    ask_amount = parser.getFloat(arr.items[1], 0);
                }
            },
            else => {},
        }

        return Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = self.base.parseTimestamp(json_val.get("ts"), time.TimeUtils.now()),
            .high = parser.getFloat(json_val.get("high") orelse .{ .float = 0 }, 0),
            .low = parser.getFloat(json_val.get("low") orelse .{ .float = 0 }, 0),
            .bid = bid_price,
            .bidVolume = bid_amount,
            .ask = ask_price,
            .askVolume = ask_amount,
            .last = parser.getFloat(json_val.get("close") orelse .{ .float = 0 }, 0),
            .baseVolume = parser.getFloat(json_val.get("vol") orelse .{ .float = 0 }, 0),
            .info = json_val,
        };
    }

    pub fn fetchOrderBook(self: *HuobiExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/market/depth?symbol={s}&depth={d}&type=step0",
            .{ self.base.api_url, market.id, limit orelse 20 });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const tick = parsed.value.get("tick") orelse return error.InvalidResponse;

        return self.parseOrderBook(tick, symbol);
    }

    fn parseOrderBook(self: *HuobiExchange, json_val: std.json.Value, symbol: []const u8) !OrderBook {
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
        self: *HuobiExchange,
        symbol: []const u8,
        timeframe: []const u8,
        since: ?i64,
        limit: ?u32,
    ) ![]OHLCV {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        // Map timeframe to Huobi period
        const period = switch (timeframe[0]) {
            '1' => switch (timeframe[1]) {
                'm' => "1min",
                'h' => "60min",
                'd' => "1day",
                'w' => "1week",
                else => "1min",
            },
            '5' => "5min",
            '1' => "60min",
            '4' => "4hour",
            '1' => "1day",
            else => "1min",
        };

        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{s}/market/history/kline?symbol={s}&period={s}",
            .{ self.base.api_url, market.id, period }));

        if (since) |s| {
            try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
                "&size={d}", .{limit orelse 100}));
        }

        const url = try self.allocator.dupe(u8, url_buf.items);
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        return try self.parseOHLCV(parsed.value, symbol);
    }

    fn parseOHLCV(self: *HuobiExchange, json_val: std.json.Value, symbol: []const u8) ![]OHLCV {
        const parser = &self.base.json_parser;

        var ohlcvs = std.ArrayList(OHLCV).init(self.allocator);
        defer ohlcvs.deinit();

        const data = json_val.get("data") orelse json_val;

        switch (data) {
            .array => |arr| {
                for (arr.items) |item| {
                    const ohlcv = OHLCV{
                        .timestamp = parser.getInt(item.get("id") orelse .{ .integer = 0 }, 0) * 1000,
                        .open = parser.getFloat(item.get("open") orelse .{ .float = 0 }, 0),
                        .high = parser.getFloat(item.get("high") orelse .{ .float = 0 }, 0),
                        .low = parser.getFloat(item.get("low") orelse .{ .float = 0 }, 0),
                        .close = parser.getFloat(item.get("close") orelse .{ .float = 0 }, 0),
                        .volume = parser.getFloat(item.get("vol") orelse .{ .float = 0 }, 0),
                    };
                    try ohlcvs.append(ohlcv);
                }
            },
            else => {},
        }

        return try ohlcvs.toOwnedSlice();
    }

    pub fn fetchTrades(self: *HuobiExchange, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{s}/market/history/trade?symbol={s}", .{ self.base.api_url, market.id }));

        if (limit) |l| {
            try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator, "&size={d}", .{l}));
        }

        const url = try self.allocator.dupe(u8, url_buf.items);
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        return try self.parseTrades(parsed.value, symbol);
    }

    fn parseTrades(self: *HuobiExchange, json_val: std.json.Value, symbol: []const u8) ![]Trade {
        const parser = &self.base.json_parser;

        var trades = std.ArrayList(Trade).init(self.allocator);
        defer trades.deinit();

        const data = json_val.get("data") orelse json_val;

        switch (data) {
            .array => |arr| {
                for (arr.items) |item| {
                    const trade_data = item.get("data") orelse item;
                    switch (trade_data) {
                        .array => |trade_arr| {
                            for (trade_arr.items) |trade| {
                                const t = try self.parseTrade(trade, symbol);
                                try trades.append(t);
                            }
                        },
                        else => {
                            const t = try self.parseTrade(trade_data, symbol);
                            try trades.append(t);
                        },
                    }
                }
            },
            else => {},
        }

        return try trades.toOwnedSlice();
    }

    fn parseTrade(self: *HuobiExchange, json_val: std.json.Value, symbol: []const u8) !Trade {
        const parser = &self.base.json_parser;

        const side_str = parser.getString(json_val, "direction", "") orelse "";
        const is_buy = std.mem.eql(u8, side_str, "buy");

        return Trade{
            .id = parser.getString(json_val, "id", "") orelse "",
            .timestamp = self.base.parseTimestamp(json_val.get("ts"), time.TimeUtils.now()),
            .datetime = try self.base.parseDatetime(self.allocator, self.base.parseTimestamp(json_val.get("ts"), time.TimeUtils.now())),
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

    pub fn fetchBalance(self: *HuobiExchange) !Balance {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        // First, get account ID if not set
        if (self.account_id == null) {
            const account_url = try std.fmt.allocPrint(self.allocator, "{s}/v1/account/accounts", .{self.base.api_url});
            defer self.allocator.free(account_url);

            var params = std.StringHashMap([]const u8).init(self.allocator);
            defer params.deinit();

            var headers = std.StringHashMap([]const u8).init(self.allocator);
            defer {
                var iter = headers.iterator();
                while (iter.next()) |entry| {
                    self.allocator.free(entry.key_ptr.*);
                    self.allocator.free(entry.value_ptr.*);
                }
                headers.deinit();
            }

            try self.authenticate("GET", "/v1/account/accounts", params, null, &headers);

            const account_response = try self.base.http_client.get(account_url, headers);
            defer account_response.deinit(self.allocator);

            const parser = &self.base.json_parser;
            const account_parsed = try parser.parse(account_response.body);

            const accounts = account_parsed.value.get("data") orelse return error.InvalidResponse;
            if (accounts.array) |arr| {
                if (arr.items.len > 0) {
                    const id_str = parser.getString(arr.items[0], "id", "") orelse "";
                    self.account_id = try self.allocator.dupe(u8, id_str);
                }
            }
        }

        if (self.account_id == null) {
            return error.AccountIdRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/v1/account/accounts/{s}/balance", .{ self.base.api_url, self.account_id.? });
        defer self.allocator.free(url);

        var params = std.StringHashMap([]const u8).init(self.allocator);
        defer params.deinit();

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        try self.authenticate("GET", "/v1/account/accounts/{s}/balance", params, null, &headers);

        const response = try self.base.http_client.get(url, headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        var total_free: f64 = 0;
        var total_used: f64 = 0;

        const data = parsed.value.get("data") orelse return error.InvalidResponse;
        const list = data.get("list") orelse data;

        switch (list) {
            .array => |arr| {
                for (arr.items) |balance| {
                    const currency = parser.getString(balance, "currency", "") orelse "";
                    if (std.mem.eql(u8, currency, "usdt")) {
                        const balance_type = parser.getString(balance, "type", "") orelse "";
                        const amount = parser.getFloat(balance.get("balance") orelse .{ .float = 0 }, 0);
                        if (std.mem.eql(u8, balance_type, "trade")) {
                            total_free = amount;
                        } else if (std.mem.eql(u8, balance_type, "frozen")) {
                            total_used = amount;
                        }
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
};

// Factory functions
pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*HuobiExchange {
    return HuobiExchange.init(allocator, auth_config, false);
}

pub fn createCN(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*HuobiExchange {
    return HuobiExchange.init(allocator, auth_config, true);
}
