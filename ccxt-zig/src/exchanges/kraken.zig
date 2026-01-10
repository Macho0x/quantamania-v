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

// Kraken Exchange Implementation
pub const KrakenExchange = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    api_key: ?[]const u8,
    secret_key: ?[]const u8,

    // API endpoints
    const API_URL = "https://api.kraken.com";
    const API_URL_ALT = "https://api.kraken.com";
    const WS_URL = "wss://ws.kraken.com";

    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*KrakenExchange {
        const self = try allocator.create(KrakenExchange);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.api_key = auth_config.apiKey;
        self.secret_key = auth_config.apiSecret;

        var http_client = try http.HttpClient.init(allocator);
        errdefer http_client.deinit();

        const name = try allocator.dupe(u8, "kraken");
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
            .rate_limit = 20, // Tier-based: 20-40 calls/second
            .rate_limit_window_ms = 1000,
            .request_counter = 0,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .json_parser = json.JsonParser.init(allocator),
        };

        try self.base.headers.put(try allocator.dupe(u8, "User-Agent"), try allocator.dupe(u8, self.base.user_agent));
        try self.base.headers.put(try allocator.dupe(u8, "Accept"), try allocator.dupe(u8, "application/json"));

        return self;
    }

    pub fn deinit(self: *KrakenExchange) void {
        if (self.api_key) |k| self.allocator.free(k);
        if (self.secret_key) |s| self.allocator.free(s);
        self.base.deinit();
        self.allocator.destroy(self);
    }

    // Kraken-specific authentication
    fn authenticate(self: *KrakenExchange, endpoint: []const u8, body: ?[]const u8, headers: *std.StringHashMap([]const u8)) !void {
        if (self.api_key) |key| {
            try headers.put(try self.allocator.dupe(u8, "API-Key"), try self.allocator.dupe(u8, key));
        }

        if (self.secret_key) |secret| {
            const nonce = try std.fmt.allocPrint(self.allocator, "{d}", .{time.TimeUtils.now()});
            defer self.allocator.free(nonce);

            var signed_data = std.ArrayList(u8).init(self.allocator);
            defer signed_data.deinit();

            try signed_data.appendSlice(nonce);
            if (body) |b| {
                try signed_data.appendSlice(b);
            }

            const signature = try crypto.Signer.hmacSha256Base64(self.allocator, secret, signed_data.items);
            defer self.allocator.free(signature);

            try headers.put(try self.allocator.dupe(u8, "API-Sign"), signature);
            try headers.put(try self.allocator.dupe(u8, "API-Nonce"), nonce);
        }
    }

    // ==================== Market Data ====================

    pub fn fetchMarkets(self: *KrakenExchange) ![]Market {
        if (self.base.isMarketsCacheValid()) {
            return self.base.markets.?;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/0/public/AssetPairs", .{self.base.api_url});
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        var markets = std.ArrayList(Market).init(self.allocator);
        defer markets.deinit();

        const result = parsed.value.get("result") orelse return error.InvalidResponse;
        const pairs = result.get("") orelse result;

        switch (pairs) {
            .object => |obj| {
                var it = obj.iterator();
                while (it.next()) |entry| {
                    const market = try self.parseMarket(entry.key_ptr.*, entry.value_ptr.*);
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

    fn parseMarket(self: *KrakenExchange, id: []const u8, json_val: std.json.Value) !Market {
        const parser = &self.base.json_parser;

        const base_asset = parser.getString(json_val, "base", "") orelse "";
        const quote_asset = parser.getString(json_val, "quote", "") orelse "";

        // Kraken uses XBT for Bitcoin
        const normalized_base = if (std.mem.eql(u8, base_asset, "XBT")) "BTC" else base_asset;
        const normalized_quote = if (std.mem.eql(u8, quote_asset, "XBT")) "BTC" else quote_asset;

        const symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ normalized_base, normalized_quote });
        const base_copy = try self.allocator.dupe(u8, normalized_base);
        const quote_copy = try self.allocator.dupe(u8, normalized_quote);

        // Determine if it's a futures pair
        const is_futures = std.mem.indexOf(u8, id, "XBT") != null and
            (std.mem.indexOf(u8, id, "PERP") != null or std.mem.indexOf(u8, id, "futures") != null);
        const is_spot = !is_futures;

        // Parse precision
        const pair_decimals = parser.getInt(json_val.get("pair_decimals") orelse .{ .integer = 8 }, 8);
        const lot_decimals = parser.getInt(json_val.get("lot_decimals") orelse .{ .integer = 8 }, 8);

        var limits = Market.MarketLimits{};
        var precision = Market.MarketPrecision{};

        // Price precision
        if (pair_decimals > 0) {
            precision.price = @as(u8, @intCast(pair_decimals));
        }
        if (lot_decimals > 0) {
            precision.amount = @as(u8, @intCast(lot_decimals));
        }

        // Lot size from minimum order size
        const lot_multiplier = parser.getFloat(json_val.get("lot_multiplier") orelse .{ .float = 1 }, 1);
        const minimum_order_size = parser.getFloat(json_val.get("ordermin") orelse .{ .float = 0 }, 0);

        if (minimum_order_size > 0) {
            limits.amount = .{ .min = minimum_order_size, .max = null };
        }

        return Market{
            .id = try self.allocator.dupe(u8, id),
            .symbol = symbol,
            .base = base_copy,
            .quote = quote_copy,
            .baseId = try self.allocator.dupe(u8, base_asset),
            .quoteId = try self.allocator.dupe(u8, quote_asset),
            .active = true,
            .spot = is_spot,
            .margin = parser.getString(json_val, "margin", "") != null,
            .future = is_futures,
            .swap = false,
            .option = false,
            .contract = is_futures,
            .limits = limits,
            .precision = precision,
            .info = json_val,
        };
    }

    pub fn fetchTicker(self: *KrakenExchange, symbol: []const u8) !Ticker {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/0/public/Ticker?pair={s}", .{ self.base.api_url, market.id });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const result = parsed.value.get("result") orelse return error.InvalidResponse;
        const ticker_data = result.get(market.id) orelse result;

        return self.parseTicker(ticker_data, symbol);
    }

    fn parseTicker(self: *KrakenExchange, json_val: std.json.Value, symbol: []const u8) !Ticker {
        const parser = &self.base.json_parser;

        const c = json_val.get("c") orelse .{ .array = .{} };
        const h = json_val.get("h") orelse .{ .array = .{} };
        const l = json_val.get("l") orelse .{ .array = .{} };
        const v = json_val.get("v") orelse .{ .array = .{} };
        const p = json_val.get("p") orelse .{ .array = .{} };

        var last_price: f64 = 0;
        var high_price: f64 = 0;
        var low_price: f64 = 0;
        var base_vol: f64 = 0;
        var vwap: f64 = 0;

        switch (c) {
            .array => |arr| if (arr.items.len > 0) {
                last_price = parser.getFloat(arr.items[0], 0);
            },
            else => {},
        }

        switch (h) {
            .array => |arr| if (arr.items.len > 0) {
                high_price = parser.getFloat(arr.items[0], 0);
            },
            else => {},
        }

        switch (l) {
            .array => |arr| if (arr.items.len > 0) {
                low_price = parser.getFloat(arr.items[0], 0);
            },
            else => {},
        }

        switch (v) {
            .array => |arr| if (arr.items.len > 0) {
                base_vol = parser.getFloat(arr.items[0], 0);
            },
            else => {},
        }

        switch (p) {
            .array => |arr| if (arr.items.len > 0) {
                vwap = parser.getFloat(arr.items[0], 0);
            },
            else => {},
        }

        return Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = time.TimeUtils.now(),
            .high = high_price,
            .low = low_price,
            .last = last_price,
            .baseVolume = base_vol,
            .vwap = vwap,
            .info = json_val,
        };
    }

    pub fn fetchOrderBook(self: *KrakenExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/0/public/Depth?pair={s}&count={d}",
            .{ self.base.api_url, market.id, limit orelse 100 });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const result = parsed.value.get("result") orelse return error.InvalidResponse;
        const depth_data = result.get(market.id) orelse result;

        return self.parseOrderBook(depth_data, symbol);
    }

    fn parseOrderBook(self: *KrakenExchange, json_val: std.json.Value, symbol: []const u8) !OrderBook {
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
        self: *KrakenExchange,
        symbol: []const u8,
        timeframe: []const u8,
        since: ?i64,
        limit: ?u32,
    ) ![]OHLCV {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        // Kraken timeframes: 1m, 5m, 15m, 30m, 1h, 4h, 1d, 1w, 1M
        const interval = switch (timeframe[0]) {
            '1' => switch (timeframe[1]) {
                'm' => 1,
                'h' => 60,
                'd' => 1440,
                'w' => 10080,
                'M' => 43200,
                else => 1,
            },
            '5' => 5,
            '1' => 60,
            '4' => 240,
            else => 1,
        };

        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{s}/0/public/OHLC?pair={s}&interval={d}",
            .{ self.base.api_url, market.id, interval }));

        if (since) |s| {
            try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
                "&since={d}", .{s}));
        }

        const url = try self.allocator.dupe(u8, url_buf.items);
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        return try self.parseOHLCV(parsed.value, symbol);
    }

    fn parseOHLCV(self: *KrakenExchange, json_val: std.json.Value, symbol: []const u8) ![]OHLCV {
        const parser = &self.base.json_parser;

        var ohlcvs = std.ArrayList(OHLCV).init(self.allocator);
        defer ohlcvs.deinit();

        const result = json_val.get("result") orelse json_val;
        const data = result.get("") orelse result;

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
                                    .volume = parser.getFloat(candle.items[6], 0),
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

    pub fn fetchTrades(self: *KrakenExchange, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{s}/0/public/Trades?pair={s}", .{ self.base.api_url, market.id }));

        if (since) |s| {
            try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
                "&since={d}", .{s}));
        }

        const url = try self.allocator.dupe(u8, url_buf.items);
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        return try self.parseTrades(parsed.value, symbol);
    }

    fn parseTrades(self: *KrakenExchange, json_val: std.json.Value, symbol: []const u8) ![]Trade {
        const parser = &self.base.json_parser;

        var trades = std.ArrayList(Trade).init(self.allocator);
        defer trades.deinit();

        const result = json_val.get("result") orelse json_val;
        const data = result.get("") orelse result;

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

    fn parseTrade(self: *KrakenExchange, json_val: std.json.Value, symbol: []const u8) !Trade {
        const parser = &self.base.json_parser;

        switch (json_val) {
            .array => |arr| {
                if (arr.items.len >= 4) {
                    const price = parser.getFloat(arr.items[0], 0);
                    const amount = parser.getFloat(arr.items[1], 0);
                    const ts = parser.getFloat(arr.items[2], 0);
                    const side_str = parser.getString(arr.items[3], "", "") orelse "";
                    const is_buy = std.mem.eql(u8, side_str, "b");

                    return Trade{
                        .id = try self.allocator.dupe(u8, ""),
                        .timestamp = @intFromFloat(ts * 1000),
                        .datetime = try self.base.parseDatetime(self.allocator, @intFromFloat(ts * 1000)),
                        .symbol = try self.allocator.dupe(u8, symbol),
                        .type = .spot,
                        .side = if (is_buy) "buy" else "sell",
                        .price = price,
                        .amount = amount,
                        .cost = price * amount,
                        .info = json_val,
                    };
                }
            },
            else => {},
        }

        return error.InvalidTradeData;
    }

    // ==================== Private Methods ====================

    pub fn fetchBalance(self: *KrakenExchange) !Balance {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/0/private/Balance", .{self.base.api_url});
        defer self.allocator.free(url);

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        const nonce = try std.fmt.allocPrint(self.allocator, "{{\"nonce\":\"{d}\"}}", .{time.TimeUtils.now()});
        defer self.allocator.free(nonce);
        try body.appendSlice(nonce);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        try self.authenticate("/0/private/Balance", body.items, &headers);

        const response = try self.base.http_client.post(url, headers, body.items);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const result = parsed.value.get("result") orelse return error.InvalidResponse;

        var total_free: f64 = 0;
        var total_used: f64 = 0;

        switch (result) {
            .object => |obj| {
                var it = obj.iterator();
                while (it.next()) |entry| {
                    const balance = parser.getFloat(entry.value_ptr.*, 0);
                    if (std.mem.eql(u8, entry.key_ptr.*, "USDT")) {
                        total_free = balance;
                    }
                    break;
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
        self: *KrakenExchange,
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

        var order_json = std.ArrayList(u8).init(self.allocator);
        defer order_json.deinit();

        const nonce = time.TimeUtils.now();
        try order_json.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{{\"nonce\":\"{d}\",\"ordertype\":\"{s}\",\"type\":\"{s}\",\"volume\":\"{d}\",\"pair\":\"{s}\"",
            .{ nonce, type_str, side_str, amount, market.id }));

        if (price) |p| {
            try order_json.appendSlice(try std.fmt.allocPrint(self.allocator,
                ",\"price\":\"{d}\"", .{p}));
        }

        try order_json.append('}');

        const url = try std.fmt.allocPrint(self.allocator, "{s}/0/private/AddOrder", .{self.base.api_url});
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

        try self.authenticate("/0/private/AddOrder", order_json.items, &headers);

        const response = try self.base.http_client.post(url, headers, order_json.items);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const result = parsed.value.get("result") orelse return error.InvalidResponse;
        const txid = parser.getString(result, "txid", "") orelse "";

        return Order{
            .id = try self.allocator.dupe(u8, txid),
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

    pub fn cancelOrder(self: *KrakenExchange, order_id: []const u8, symbol: []const u8) !Order {
        _ = symbol;
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        const nonce = time.TimeUtils.now();
        try body.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{{\"nonce\":\"{d}\",\"txid\":\"{s}\"}}", .{ nonce, order_id }));

        const url = try std.fmt.allocPrint(self.allocator, "{s}/0/private/CancelOrder", .{self.base.api_url});
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

        try self.authenticate("/0/private/CancelOrder", body.items, &headers);

        const response = try self.base.http_client.post(url, headers, body.items);
        defer response.deinit(self.allocator);

        return Order{
            .id = try self.allocator.dupe(u8, order_id),
            .timestamp = time.TimeUtils.now(),
            .datetime = try self.base.parseDatetime(self.allocator, time.TimeUtils.now()),
            .symbol = try self.allocator.dupe(u8, ""),
            .type = OrderType.limit,
            .side = .buy,
            .price = 0,
            .amount = 0,
            .filled = 0,
            .remaining = 0,
            .status = .canceled,
            .info = null,
        };
    }
};

// Factory function
pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*KrakenExchange {
    return KrakenExchange.init(allocator, auth_config);
}
