const std = @import("std");
const exchange = @import("../base/exchange.zig");
const auth = @import("../base/auth.zig");
const errors = @import("../base/errors.zig");
const http = @import("../base/http.zig");
const json = @import("../utils/json.zig");
const time = @import("../utils/time.zig");
const crypto = @import("../utils/crypto.zig");
const binance_errors = @import("./errors/binance_errors.zig");

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

// Binance Exchange Implementation
pub const BinanceExchange = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    api_key: ?[]const u8,
    secret_key: ?[]const u8,
    testnet: bool,

    // API endpoints
    const API_URL = "https://api.binance.com";
    const API_URL_FUTURES = "https://fapi.binance.com";
    const API_URL_COIN = "https://dapi.binance.com";
    const TESTNET_URL = "https://testnet.binance.vision";
    const WS_URL = "wss://stream.binance.com:9443/ws";
    const WS_URL_FUTURES = "wss://fstream.binance.com/ws";

    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig, testnet: bool) !*BinanceExchange {
        const self = try allocator.create(BinanceExchange);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.api_key = auth_config.apiKey;
        self.secret_key = auth_config.apiSecret;
        self.testnet = testnet;

        var http_client = try http.HttpClient.init(allocator);
        errdefer http_client.deinit();

        const base_name = try allocator.dupe(u8, "binance");
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
            .rate_limit = 1200, // 1200 requests per minute
            .rate_limit_window_ms = 60000,
            .request_counter = 0,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .json_parser = json.JsonParser.init(allocator),
        };

        // Add default headers
        try self.base.headers.put(try allocator.dupe(u8, "User-Agent"), try allocator.dupe(u8, self.base.user_agent));
        try self.base.headers.put(try allocator.dupe(u8, "Accept"), try allocator.dupe(u8, "application/json"));

        return self;
    }

    pub fn deinit(self: *BinanceExchange) void {
        if (self.api_key) |k| self.allocator.free(k);
        if (self.secret_key) |s| self.allocator.free(s);
        self.base.deinit();
        self.allocator.destroy(self);
    }

    // Get current API URL based on type
    fn getApiUrl(self: *BinanceExchange, endpoint: []const u8, is_futures: bool, is_coin: bool) []const u8 {
        _ = self;
        const prefix = if (is_coin) API_URL_COIN else if (is_futures) API_URL_FUTURES else API_URL;
        return prefix;
    }

    // Sign request for private endpoints
    fn signRequest(
        self: *BinanceExchange,
        method: []const u8,
        endpoint: []const u8,
        query_params: ?std.StringHashMap([]const u8),
        body: ?[]const u8,
        is_futures: bool,
        is_coin: bool,
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

        // Add API key header
        if (self.api_key) |key| {
            try headers.put(try self.allocator.dupe(u8, "X-MBX-APIKEY"), try self.allocator.dupe(u8, key));
        }

        // For public endpoints, no signature needed
        if (self.secret_key == null) return headers;

        // Build query string with timestamp
        var query_string = std.ArrayList(u8).init(self.allocator);
        defer query_string.deinit();

        const timestamp = time.TimeUtils.now();
        try query_string.appendSlice(try std.fmt.allocPrint(self.allocator, "timestamp={d}", .{timestamp}));

        if (query_params) |params| {
            var iter = params.iterator();
            while (iter.next()) |entry| {
                try query_string.append('&');
                try query_string.appendSlice(entry.key_ptr.*);
                try query_string.append('=');
                try query_string.appendSlice(entry.value_ptr.*);
            }
        }

        // Generate signature
        const signature = try crypto.Signer.hmacSha256Hex(self.secret_key.?, query_string.items);
        try query_string.appendSlice("&signature=");
        try query_string.appendSlice(&signature);

        // For GET/DELETE, query params go in URL; for POST, they go in body
        const final_url = if (std.mem.eql(u8, method, "GET") or std.mem.eql(u8, method, "DELETE"))
            std.fmt.allocPrint(self.allocator, "{s}{s}?{s}", .{ self.getApiUrl(endpoint, is_futures, is_coin), endpoint, query_string.items })
        else
            null;

        if (final_url) |url| {
            _ = url; // Would be used for request
        }

        if (!std.mem.eql(u8, method, "GET") and !std.mem.eql(u8, method, "DELETE")) {
            try headers.put(try self.allocator.dupe(u8, "Content-Type"), try self.allocator.dupe(u8, "application/x-www-form-urlencoded"));
        }

        return headers;
    }

    // ==================== Market Data ====================

    pub fn fetchMarkets(self: *BinanceExchange) ![]Market {
        // Check cache first
        if (self.base.isMarketsCacheValid()) {
            return self.base.markets.?;
        }

        // Fetch from API - use futures endpoint to get all markets
        const url = try std.fmt.allocPrint(self.allocator, "{s}/api/v3/exchangeInfo", .{self.base.api_url});
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        var markets = std.ArrayList(Market).init(self.allocator);
        defer markets.deinit();

        const symbols = parsed.value.get("symbols") orelse return error.InvalidResponse;

        switch (symbols) {
            .array => |arr| {
                for (arr.items) |symbol| {
                    const market = try self.parseMarket(symbol);
                    try markets.append(market);
                }
            },
            else => return error.InvalidResponse,
        }

        // Cache the markets
        self.base.last_markets_fetch = time.TimeUtils.now();
        const markets_copy = try markets.toOwnedSlice();
        self.base.markets = markets_copy;

        return markets_copy;
    }

    fn parseMarket(self: *BinanceExchange, json_val: std.json.Value) !Market {
        const parser = &self.base.json_parser;

        const id = parser.getString(json_val, "symbol", "") orelse "";
        const base_asset = parser.getString(json_val, "baseAsset", "") orelse "";
        const quote_asset = parser.getString(json_val, "quoteAsset", "") orelse "";
        const symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base_asset, quote_asset });
        const base_copy = try self.allocator.dupe(u8, base_asset);
        const quote_copy = try self.allocator.dupe(u8, quote_asset);

        const status_str = parser.getString(json_val, "status", "TRADING") orelse "TRADING";
        const is_active = std.mem.eql(u8, status_str, "TRADING");

        // Parse filters for limits and precision
        var limits = Market.MarketLimits{};
        var precision = Market.MarketPrecision{};

        const filters = json_val.get("filters") orelse .{ .array = .{} };
        switch (filters) {
            .array => |f| {
                for (f.items) |filter| {
                    const filter_type = parser.getString(filter, "filterType", "") orelse "";
                    if (std.mem.eql(u8, filter_type, "PRICE_FILTER")) {
                        const min_price = parser.getFloat(filter.get("minPrice") orelse .{ .float = 0 }, 0);
                        const max_price = parser.getFloat(filter.get("maxPrice") orelse .{ .float = 0 }, 0);
                        const tick_size = parser.getFloat(filter.get("tickSize") orelse .{ .float = 0 }, 0);
                        limits.price = .{
                            .min = if (min_price > 0) min_price else null,
                            .max = if (max_price > 0) max_price else null,
                        };
                        if (tick_size > 0) {
                            precision.price = @as(u8, @intFromFloat(-@log10(tick_size)));
                        }
                    } else if (std.mem.eql(u8, filter_type, "LOT_SIZE")) {
                        const min_qty = parser.getFloat(filter.get("minQty") orelse .{ .float = 0 }, 0);
                        const max_qty = parser.getFloat(filter.get("maxQty") orelse .{ .float = 0 }, 0);
                        const step_size = parser.getFloat(filter.get("stepSize") orelse .{ .float = 0 }, 0);
                        limits.amount = .{
                            .min = if (min_qty > 0) min_qty else null,
                            .max = if (max_qty > 0) max_qty else null,
                        };
                        if (step_size > 0) {
                            precision.amount = @as(u8, @intFromFloat(-@log10(step_size)));
                        }
                    } else if (std.mem.eql(u8, filter_type, "MIN_NOTIONAL")) {
                        const min_notional = parser.getFloat(filter.get("minNotional") orelse .{ .float = 0 }, 0);
                        limits.cost = .{
                            .min = if (min_notional > 0) min_notional else null,
                            .max = null,
                        };
                    }
                }
            },
            else => {},
        }

        // Determine market type
        const is_futures = std.mem.eql(u8, id, id[0..@min(4, id.len)]) or
            std.mem.indexOf(u8, id, "PERP") != null;
        const is_spot = !is_futures and std.mem.indexOf(u8, id, "DOWN") == null and
            std.mem.indexOf(u8, id, "UP") == null;

        return Market{
            .id = try self.allocator.dupe(u8, id),
            .symbol = symbol,
            .base = base_copy,
            .quote = quote_copy,
            .baseId = try self.allocator.dupe(u8, base_asset),
            .quoteId = try self.allocator.dupe(u8, quote_asset),
            .active = is_active,
            .spot = is_spot,
            .margin = is_spot, // Spot markets support margin
            .future = is_futures,
            .swap = false,
            .option = false,
            .contract = is_futures,
            .limits = limits,
            .precision = precision,
            .info = json_val,
            .leverage = if (is_futures) 10.0 else null,
        };
    }

    pub fn fetchTicker(self: *BinanceExchange, symbol: []const u8) !Ticker {
        // Find market to get exchange symbol format
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/api/v3/ticker/24hr?symbol={s}", .{ self.base.api_url, market.id });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        return self.parseTicker(parsed.value, symbol);
    }

    fn parseTicker(self: *BinanceExchange, json_val: std.json.Value, symbol: []const u8) !Ticker {
        const parser = &self.base.json_parser;

        return Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = self.base.parseTimestamp(json_val.get("closeTime"), time.TimeUtils.now()),
            .high = parser.getFloat(json_val.get("highPrice") orelse .{ .float = 0 }, 0),
            .low = parser.getFloat(json_val.get("lowPrice") orelse .{ .float = 0 }, 0),
            .bid = parser.getFloat(json_val.get("bidPrice") orelse .{ .float = 0 }, 0),
            .bidVolume = parser.getFloat(json_val.get("bidQty") orelse .{ .float = 0 }, 0),
            .ask = parser.getFloat(json_val.get("askPrice") orelse .{ .float = 0 }, 0),
            .askVolume = parser.getFloat(json_val.get("askQty") orelse .{ .float = 0 }, 0),
            .last = parser.getFloat(json_val.get("lastPrice") orelse .{ .float = 0 }, 0),
            .baseVolume = parser.getFloat(json_val.get("quoteVolume") orelse .{ .float = 0 }, 0),
            .quoteVolume = parser.getFloat(json_val.get("volume") orelse .{ .float = 0 }, 0),
            .percentage = parser.getFloat(json_val.get("priceChangePercent") orelse .{ .float = 0 }, 0),
            .info = json_val,
        };
    }

    pub fn fetchOrderBook(self: *BinanceExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const limit_val = limit orelse 100;
        const safe_limit = @min(limit_val, 5000);

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/api/v3/depth?symbol={s}&limit={d}",
            .{ self.base.api_url, market.id, safe_limit });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        return self.parseOrderBook(parsed.value, symbol);
    }

    fn parseOrderBook(self: *BinanceExchange, json_val: std.json.Value, symbol: []const u8) !OrderBook {
        const parser = &self.base.json_parser;
        const timestamp = self.base.parseTimestamp(json_val.get("lastUpdateId"), time.TimeUtils.now());

        // Parse bids
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

        // Parse asks
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
        self: *BinanceExchange,
        symbol: []const u8,
        timeframe: []const u8,
        since: ?i64,
        limit: ?u32,
    ) ![]OHLCV {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        var query = std.ArrayList(u8).init(self.allocator);
        defer query.deinit();

        try query.appendSlice(try std.fmt.allocPrint(self.allocator,
            "symbol={s}&interval={s}", .{ market.id, timeframe }));

        if (since) |s| {
            try query.appendSlice(try std.fmt.allocPrint(self.allocator,
                "&startTime={d}", .{s}));
        }

        if (limit) |l| {
            try query.appendSlice(try std.fmt.allocPrint(self.allocator,
                "&limit={d}", .{l}));
        }

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/api/v3/klines?{s}", .{ self.base.api_url, query.items });
        defer self.allocator.free(url);

        const response = try self.base.http_client.get(url, null);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        return try self.parseOHLCV(parsed.value, symbol);
    }

    fn parseOHLCV(self: *BinanceExchange, json_val: std.json.Value, symbol: []const u8) ![]OHLCV {
        const parser = &self.base.json_parser;

        var ohlcvs = std.ArrayList(OHLCV).init(self.allocator);
        defer ohlcvs.deinit();

        switch (json_val) {
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
                                    .quoteVolume = if (candle.items.len > 7)
                                        parser.getFloat(candle.items[7], 0) else null,
                                    .count = if (candle.items.len > 8)
                                        @as(u32, @intCast(parser.getInt(candle.items[8], 0))) else null,
                                };
                                try ohlcvs.append(ohlcv);
                            }
                        },
                        else => {},
                    }
                }
            },
            else => return error.InvalidResponse,
        }

        return try ohlcvs.toOwnedSlice();
    }

    pub fn fetchTrades(self: *BinanceExchange, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice(try std.fmt.allocPrint(self.allocator,
            "{s}/api/v3/trades?symbol={s}", .{ self.base.api_url, market.id }));

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

        return try self.parseTrades(parsed.value, symbol);
    }

    fn parseTrades(self: *BinanceExchange, json_val: std.json.Value, symbol: []const u8) ![]Trade {
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

    fn parseTrade(self: *BinanceExchange, json_val: std.json.Value, symbol: []const u8) !Trade {
        const parser = &self.base.json_parser;

        const id = parser.getString(json_val, "id", "") orelse "";
        const order_id = parser.getString(json_val, "orderId", "") orelse "";
        const side_str = parser.getString(json_val, "isBuyerMaker", "true") orelse "true";
        const is_buyer = !std.mem.eql(u8, side_str, "false") and
            std.mem.eql(u8, side_str, "false");

        return Trade{
            .id = try self.allocator.dupe(u8, id),
            .order = try self.allocator.dupe(u8, order_id),
            .timestamp = self.base.parseTimestamp(json_val.get("time"), 0),
            .datetime = try self.base.parseDatetime(self.allocator, self.base.parseTimestamp(json_val.get("time"), 0)),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = .spot,
            .side = if (is_buyer) "sell" else "buy",
            .price = parser.getFloat(json_val.get("price") orelse .{ .float = 0 }, 0),
            .amount = parser.getFloat(json_val.get("qty") orelse .{ .float = 0 }, 0),
            .cost = parser.getFloat(json_val.get("quoteQty") orelse .{ .float = 0 }, 0),
            .takerOrMaker = if (std.mem.eql(u8, side_str, "false")) "maker" else "taker",
            .info = json_val,
        };
    }

    // ==================== Private Methods ====================

    pub fn fetchBalance(self: *BinanceExchange) !Balance {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/api/v3/account?timestamp={d}",
            .{ self.base.api_url, time.TimeUtils.now() });
        defer self.allocator.free(url);

        const headers = try self.signRequest("GET", "/api/v3/account", null, null, false, false);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        const response = try self.base.http_client.get(url, headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const balances = parsed.value.get("balances") orelse return error.InvalidResponse;
        var total_free: f64 = 0;
        var total_used: f64 = 0;

        switch (balances) {
            .array => |arr| {
                for (arr.items) |bal| {
                    const free = parser.getFloat(bal.get("free") orelse .{ .float = 0 }, 0);
                    const locked = parser.getFloat(bal.get("locked") orelse .{ .float = 0 }, 0);
                    if (free > 0 or locked > 0) {
                        total_free = free;
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
        self: *BinanceExchange,
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
            "symbol={s}&side={s}&type={s}&quantity={d}&timestamp={d}",
            .{ market.id, side_str, type_str, amount, time.TimeUtils.now() }));

        if (price) |p| {
            try body.appendSlice(try std.fmt.allocPrint(self.allocator,
                "&price={d}", .{p}));
        }

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/api/v3/order", .{ self.base.api_url });
        defer self.allocator.free(url);

        const headers = try self.signRequest("POST", "/api/v3/order", null, body.items, false, false);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        const response = try self.base.http_client.post(url, headers, body.items);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        return Order{
            .id = parser.getString(parsed.value, "orderId", "") orelse "",
            .timestamp = self.base.parseTimestamp(parsed.value.get("transactTime"), time.TimeUtils.now()),
            .datetime = try self.base.parseDatetime(self.allocator, self.base.parseTimestamp(parsed.value.get("transactTime"), time.TimeUtils.now())),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = OrderType.limit,
            .side = if (std.mem.eql(u8, side_str, "BUY")) .buy else .sell,
            .price = price orelse 0,
            .amount = amount,
            .filled = 0,
            .remaining = amount,
            .status = .open,
            .info = parsed.value,
        };
    }

    pub fn cancelOrder(self: *BinanceExchange, order_id: []const u8, symbol: []const u8) !Order {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        try body.appendSlice(try std.fmt.allocPrint(self.allocator,
            "symbol={s}&orderId={s}&timestamp={d}",
            .{ market.id, order_id, time.TimeUtils.now() }));

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/api/v3/order", .{ self.base.api_url });
        defer self.allocator.free(url);

        const headers = try self.signRequest("DELETE", "/api/v3/order", null, body.items, false, false);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        const response = try self.base.http_client.delete(url, headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const status_str = parser.getString(parsed.value, "status", "") orelse "";
        const status = if (std.mem.eql(u8, status_str, "CANCELED")) .canceled else .closed;

        return Order{
            .id = try self.allocator.dupe(u8, order_id),
            .timestamp = self.base.parseTimestamp(parsed.value.get("updateTime"), time.TimeUtils.now()),
            .datetime = try self.base.parseDatetime(self.allocator, self.base.parseTimestamp(parsed.value.get("updateTime"), time.TimeUtils.now())),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = .limit,
            .side = if (std.mem.eql(u8, parser.getString(parsed.value, "side", "") orelse "", "BUY")) .buy else .sell,
            .price = parser.getFloat(parsed.value.get("price") orelse .{ .float = 0 }, 0),
            .amount = parser.getFloat(parsed.value.get("origQty") orelse .{ .float = 0 }, 0),
            .filled = parser.getFloat(parsed.value.get("executedQty") orelse .{ .float = 0 }, 0),
            .remaining = parser.getFloat(parsed.value.get("origQty") orelse .{ .float = 0 }, 0) -
                parser.getFloat(parsed.value.get("executedQty") orelse .{ .float = 0 }, 0),
            .status = status,
            .info = parsed.value,
        };
    }

    pub fn fetchOrder(self: *BinanceExchange, order_id: []const u8, symbol: []const u8) !Order {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        var query = std.StringHashMap([]const u8).init(self.allocator);
        defer query.deinit();

        try query.put("symbol", market.id);
        try query.put("orderId", order_id);
        try query.put("timestamp", try std.fmt.allocPrint(self.allocator, "{d}", .{time.TimeUtils.now()}));

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/api/v3/order", .{ self.base.api_url });
        defer self.allocator.free(url);

        const headers = try self.signRequest("GET", "/api/v3/order", query, null, false, false);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        const response = try self.base.http_client.get(url, headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        const side_str = parser.getString(parsed.value, "side", "") orelse "";

        return Order{
            .id = try self.allocator.dupe(u8, order_id),
            .timestamp = self.base.parseTimestamp(parsed.value.get("time"), time.TimeUtils.now()),
            .datetime = try self.base.parseDatetime(self.allocator, self.base.parseTimestamp(parsed.value.get("time"), time.TimeUtils.now())),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = OrderType.limit,
            .side = if (std.mem.eql(u8, side_str, "BUY")) .buy else .sell,
            .price = parser.getFloat(parsed.value.get("price") orelse .{ .float = 0 }, 0),
            .amount = parser.getFloat(parsed.value.get("origQty") orelse .{ .float = 0 }, 0),
            .filled = parser.getFloat(parsed.value.get("executedQty") orelse .{ .float = 0 }, 0),
            .remaining = parser.getFloat(parsed.value.get("origQty") orelse .{ .float = 0 }, 0) -
                parser.getFloat(parsed.value.get("executedQty") orelse .{ .float = 0 }, 0),
            .status = .open,
            .info = parsed.value,
        };
    }

    pub fn fetchOpenOrders(self: *BinanceExchange, symbol: ?[]const u8) ![]Order {
        if (self.api_key == null or self.secret_key == null) {
            return error.AuthenticationRequired;
        }

        var query = std.StringHashMap([]const u8).init(self.allocator);
        defer query.deinit();

        try query.put("timestamp", try std.fmt.allocPrint(self.allocator, "{d}", .{time.TimeUtils.now()}));

        if (symbol) |s| {
            const market = self.base.findMarket(s) orelse
                return error.SymbolNotFound;
            try query.put("symbol", market.id);
        }

        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/api/v3/openOrders", .{ self.base.api_url });
        defer self.allocator.free(url);

        const headers = try self.signRequest("GET", "/api/v3/openOrders", query, null, false, false);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        const response = try self.base.http_client.get(url, headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);

        var orders = std.ArrayList(Order).init(self.allocator);
        defer orders.deinit();

        switch (parsed.value) {
            .array => |arr| {
                for (arr.items) |item| {
                    const order = try self.parseOrderFromList(item);
                    try orders.append(order);
                }
            },
            else => {},
        }

        return try orders.toOwnedSlice();
    }

    fn parseOrderFromList(self: *BinanceExchange, json_val: std.json.Value) !Order {
        const parser = &self.base.json_parser;
        const side_str = parser.getString(json_val, "side", "") orelse "";
        const status_str = parser.getString(json_val, "status", "") orelse "";

        const market_id = parser.getString(json_val, "symbol", "") orelse "";
        const market = self.base.findMarketById(market_id) orelse
            Market{ .id = "", .symbol = market_id, .base = "", .quote = "" };

        const symbol = try self.allocator.dupe(u8, market.symbol);

        return Order{
            .id = parser.getString(json_val, "orderId", "") orelse "",
            .timestamp = self.base.parseTimestamp(json_val.get("time"), time.TimeUtils.now()),
            .datetime = try self.base.parseDatetime(self.allocator, self.base.parseTimestamp(json_val.get("time"), time.TimeUtils.now())),
            .symbol = symbol,
            .type = OrderType.limit,
            .side = if (std.mem.eql(u8, side_str, "BUY")) .buy else .sell,
            .price = parser.getFloat(json_val.get("price") orelse .{ .float = 0 }, 0),
            .amount = parser.getFloat(json_val.get("origQty") orelse .{ .float = 0 }, 0),
            .filled = parser.getFloat(json_val.get("executedQty") orelse .{ .float = 0 }, 0),
            .remaining = parser.getFloat(json_val.get("origQty") orelse .{ .float = 0 }, 0) -
                parser.getFloat(json_val.get("executedQty") orelse .{ .float = 0 }, 0),
            .status = if (std.mem.eql(u8, status_str, "FILLED")) .closed else .open,
            .info = json_val,
        };
    }
};

// Factory function
pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*BinanceExchange {
    return BinanceExchange.init(allocator, auth_config, false);
}

pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*BinanceExchange {
    return BinanceExchange.init(allocator, auth_config, true);
}
