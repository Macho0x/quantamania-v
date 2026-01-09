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

// Bybit Exchange Implementation
pub const BybitExchange = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    api_key: ?[]const u8,
    secret_key: ?[]const u8,
    testnet: bool,

    // API endpoints
    const API_URL = "https://api.bybit.com";
    const API_URL_TESTNET = "https://api-testnet.bybit.com";
    const WS_URL = "wss://stream.bybit.com/ws/v5/public";
    const WS_URL_TESTNET = "wss://stream-testnet.bybit.com/ws/v5/public";

    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig, testnet: bool) !*BybitExchange {
        const self = try allocator.create(BybitExchange);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.api_key = auth_config.apiKey;
        self.secret_key = auth_config.apiSecret;
        self.testnet = testnet;

        const http_client = try http.HttpClient.init(allocator);
        errdefer http_client.deinit();

        const name = try allocator.dupe(u8, "bybit");
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
            .rate_limit = 100, // Varies by endpoint
            .rate_limit_window_ms = 60000,
            .request_counter = 0,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .json_parser = json.JsonParser.init(allocator),
        };

        try self.base.headers.put(try allocator.dupe(u8, "User-Agent"), try allocator.dupe(u8, self.base.user_agent));
        try self.base.headers.put(try allocator.dupe(u8, "Accept"), try allocator.dupe(u8, "application/json"));

        return self;
    }

    pub fn deinit(self: *BybitExchange) void {
        if (self.api_key) |k| self.allocator.free(k);
        if (self.secret_key) |s| self.allocator.free(s);
        self.base.deinit();
        self.allocator.destroy(self);
    }

    // Bybit-specific authentication
    fn authenticate(
        self: *BybitExchange,
        method: []const u8,
        endpoint: []const u8,
        query_params: []const u8,
        body: ?[]const u8,
        headers: *std.StringHashMap([]const u8),
    ) !void {
        if (self.api_key) |key| {
            try headers.put(try self.allocator.dupe(u8, "X-BAPI-API-KEY"), try self.allocator.dupe(u8, key));
        }

        const timestamp = time.TimeUtils.now();
        const timestamp_str = try std.fmt.allocPrint(self.allocator, "{d}", .{timestamp});
        defer self.allocator.free(timestamp_str);

        try headers.put(try self.allocator.dupe(u8, "X-BAPI-TIMESTAMP"), try self.allocator.dupe(u8, timestamp_str));
        try headers.put(try self.allocator.dupe(u8, "X-BAPI-RECV-WINDOW"), try self.allocator.dupe(u8, "5000"));

        if (self.secret_key) |secret| {
            var message = std.ArrayList(u8).init(self.allocator);
            defer message.deinit();

            try message.appendSlice(timestamp_str);
            try message.appendSlice(self.api_key orelse "");
            try message.appendSlice(query_params);

            if (body) |b| {
                try message.appendSlice(b);
            }

            const signature = try crypto.Signer.hmacSha256Hex(secret, message.items);
            try headers.put(try self.allocator.dupe(u8, "X-BAPI-SIGN"), try self.allocator.dupe(u8, &signature));
        }
    }

    // ==================== Market Data ====================

    pub fn fetchMarkets(self: *BybitExchange) ![]Market {
        if (self.base.isMarketsCacheValid()) {
            return self.base.markets.?;
        }

        // Fetch from multiple endpoints for different market types
        const url = try std.fmt.allocPrint(self.allocator, "{s}/v5/market/instruments-info?category=linear", .{self.base.api_url});
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        var markets = std.ArrayList(Market).init(self.allocator);
        defer markets.deinit();

        const result = parsed.value.get("result") orelse return error.InvalidResponse;
        const list = result.get("list") orelse result;

        switch (list) {
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

    fn parseMarket(self: *BybitExchange, json_val: std.json.Value) !Market {
        const parser = &self.base.json_parser;

        const id = parser.getString(json_val, "symbol", "") orelse "";
        const base_asset = parser.getString(json_val, "baseCoin", "") orelse "";
        const quote_asset = parser.getString(json_val, "quoteCoin", "") orelse "";
        const symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base_asset, quote_asset });
        const base_copy = try self.allocator.dupe(u8, base_asset);
        const quote_copy = try self.allocator.dupe(u8, quote_asset);

        const status = parser.getString(json_val, "status", "") orelse "";
        const is_active = std.mem.eql(u8, status, "Trading");

        // Determine contract type
        const contract_type = parser.getString(json_val, "contractType", "") orelse "";
        const is_spot = std.mem.eql(u8, contract_type, "");
        const is_linear = std.mem.eql(u8, contract_type, "LinearPerpetual");

        const lot_size = parser.getFloat(json_val.get("lotSizeFilter").?.get("minOrderQty") orelse .{ .float = 0 }, 0);
        const tick_size = parser.getFloat(json_val.get("priceFilter").?.get("tickSize") orelse .{ .float = 0 }, 0);

        var limits = Market.MarketLimits{};
        var precision = Market.MarketPrecision{};

        if (lot_size > 0) {
            limits.amount = .{ .min = lot_size, .max = null };
        }

        if (tick_size > 0) {
            precision.price = @as(u8, @intFromFloat(-@log10(tick_size)));
        }

        return Market{
            .id = try self.allocator.dupe(u8, id),
            .symbol = symbol,
            .base = base_copy,
            .quote = quote_copy,
            .baseId = try self.allocator.dupe(u8, base_asset),
            .quoteId = try self.allocator.dupe(u8, quote_asset),
            .active = is_active,
            .spot = is_spot,
            .margin = false,
            .future = !is_spot,
            .swap = is_linear,
            .option = false,
            .contract = !is_spot,
            .limits = limits,
            .precision = precision,
            .info = json_val,
        };
    }

    pub fn fetchTicker(self: *BybitExchange, symbol: []const u8) !Ticker {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/v5/market/tickers?symbol={s}", .{ self.base.api_url, market.id });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const result = parsed.value.get("result") orelse return error.InvalidResponse;
        const list = result.get("list") orelse result;

        const ticker_data = if (list.array) |arr| arr.items[0] else json_val;

        return self.parseTicker(ticker_data, symbol);
    }

    fn parseTicker(self: *BybitExchange, json_val: std.json.Value, symbol: []const u8) !Ticker {
        const parser = &self.base.json_parser;

        return Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = self.base.parseTimestamp(json_val.get("time"), time.TimeUtils.now()),
            .high = parser.getFloat(json_val.get("highPrice24h") orelse .{ .float = 0 }, 0),
            .low = parser.getFloat(json_val.get("lowPrice24h") orelse .{ .float = 0 }, 0),
            .bid = parser.getFloat(json_val.get("bid1Price") orelse .{ .float = 0 }, 0),
            .bidVolume = parser.getFloat(json_val.get("bid1Size") orelse .{ .float = 0 }, 0),
            .ask = parser.getFloat(json_val.get("ask1Price") orelse .{ .float = 0 }, 0),
            .askVolume = parser.getFloat(json_val.get("ask1Size") orelse .{ .float = 0 }, 0),
            .last = parser.getFloat(json_val.get("lastPrice") orelse .{ .float = 0 }, 0),
            .baseVolume = parser.getFloat(json_val.get("volume24h") orelse .{ .float = 0 }, 0),
            .quoteVolume = parser.getFloat(json_val.get("turnover24h") orelse .{ .float = 0 }, 0),
            .info = json_val,
        };
    }

    pub fn fetchOrderBook(self: *BybitExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/v5/market/orderbook?symbol={s}&limit={d}",
            .{ self.base.api_url, market.id, limit orelse 25 });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const result = parsed.value.get("result") orelse return error.InvalidResponse;

        return self.parseOrderBook(result, symbol);
    }

    fn parseOrderBook(self: *BybitExchange, json_val: std.json.Value, symbol: []const u8) !OrderBook {
        const parser = &self.base.json_parser;
        const timestamp = self.base.parseTimestamp(json_val.get("ts"), time.TimeUtils.now());

        const bids_json = json_val.get("b") orelse .{ .array = .{} };
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

        const asks_json = json_val.get("a") orelse .{ .array = .{} };
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
        self: *BybitExchange,
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
            "{s}/v5/market/kline?symbol={s}&interval={s}",
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

    fn parseOHLCV(self: *BybitExchange, json_val: std.json.Value, symbol: []const u8) ![]OHLCV {
        const parser = &self.base.json_parser;

        var ohlcvs = std.ArrayList(OHLCV).init(self.allocator);
        defer ohlcvs.deinit();

        const result = json_val.get("result") orelse json_val;
        const list = result.get("list") orelse result;

        switch (list) {
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

    pub fn fetchTrades(self: *BybitExchange, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{s}/v5/market/recent-trade?symbol={s}", .{ self.base.api_url, market.id }));

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

    fn parseTrades(self: *BybitExchange, json_val: std.json.Value, symbol: []const u8) ![]Trade {
        const parser = &self.base.json_parser;

        var trades = std.ArrayList(Trade).init(self.allocator);
        defer trades.deinit();

        const result = json_val.get("result") orelse json_val;
        const list = result.get("list") orelse result;

        switch (list) {
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

    fn parseTrade(self: *BybitExchange, json_val: std.json.Value, symbol: []const u8) !Trade {
        const parser = &self.base.json_parser;

        const side_str = parser.getString(json_val, "side", "") orelse "";
        const is_buy = std.mem.eql(u8, side_str, "Buy");

        return Trade{
            .id = parser.getString(json_val, "tradeId", "") orelse "",
            .timestamp = self.base.parseTimestamp(json_val.get("time"), time.TimeUtils.now()),
            .datetime = try self.base.parseDatetime(self.allocator, self.base.parseTimestamp(json_val.get("time"), time.TimeUtils.now())),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = .spot,
            .side = if (is_buy) "buy" else "sell",
            .price = parser.getFloat(json_val.get("price") orelse .{ .float = 0 }, 0),
            .amount = parser.getFloat(json_val.get("size") orelse .{ .float = 0 }, 0),
            .cost = parser.getFloat(json_val.get("price") orelse .{ .float = 0 }, 0) *
                parser.getFloat(json_val.get("size") orelse .{ .float = 0 }, 0),
            .takerOrMaker = if (is_buy) "taker" else "taker",
            .info = json_val,
        };
    }

    // ==================== Private Methods ====================

    pub fn fetchBalance(self: *BybitExchange) !Balance {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/v5/account/wallet-balance", .{self.base.api_url});
        defer self.allocator.free(url);

        const query = "accountType=UNIFIED";
        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();
        try body.appendSlice("{}");

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        try self.authenticate("GET", "/v5/account/wallet-balance", query, body.items, &headers);

        const response = try self.base.http_client.get(url ++ "?" ++ query, headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        var total_free: f64 = 0;
        var total_used: f64 = 0;

        const result = parsed.value.get("result") orelse return error.InvalidResponse;
        const list = result.get("list") orelse result;

        switch (list) {
            .array => |arr| {
                for (arr.items) |account| {
                    const coin_list = account.get("coin") orelse .{ .array = .{} };
                    switch (coin_list) {
                        .array => |coins| {
                            for (coins.items) |coin| {
                                const currency = parser.getString(coin, "coin", "") orelse "";
                                if (std.mem.eql(u8, currency, "USDT")) {
                                    const available = parser.getFloat(coin.get("availableBalance") orelse .{ .float = 0 }, 0);
                                    const wallet = parser.getFloat(coin.get("walletBalance") orelse .{ .float = 0 }, 0);
                                    total_free = available;
                                    total_used = wallet - available;
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
        self: *BybitExchange,
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
            "{{\"category\":\"linear\",\"symbol\":\"{s}\",\"side\":\"{s}\",\"orderType\":\"{s}\",\"qty\":\"{d}\"",
            .{ market.id, side_str, type_str, amount }));

        if (price) |p| {
            try body.appendSlice(try std.fmt.allocPrint(self.allocator,
                ",\"price\":\"{d}\"", .{p}));
        }

        try body.appendSlice(",\"timeInForce\":\"GTC\"}}");

        const endpoint = "/v5/order/create";
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

        try self.authenticate("POST", endpoint, "", body.items, &headers);

        const response = try self.base.http_client.post(url, headers, body.items);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const result = parsed.value.get("result") orelse return error.InvalidResponse;
        const order_id = parser.getString(result, "orderId", "") orelse "";

        return Order{
            .id = try self.allocator.dupe(u8, order_id),
            .timestamp = time.TimeUtils.now(),
            .datetime = try self.base.parseDatetime(self.allocator, time.TimeUtils.now()),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = OrderType.limit,
            .side = if (std.mem.eql(u8, side_str, "Buy")) .buy else .sell,
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
pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*BybitExchange {
    return BybitExchange.init(allocator, auth_config, false);
}

pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*BybitExchange {
    return BybitExchange.init(allocator, auth_config, true);
}
