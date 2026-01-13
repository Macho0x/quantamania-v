const std = @import("std");
const exchange = @import("../base/exchange.zig");
const auth = @import("../base/auth.zig");
const http = @import("../base/http.zig");
const json = @import("../utils/json.zig");
const time = @import("../utils/time.zig");
const crypto = @import("../utils/crypto.zig");
const precision_utils = @import("../utils/precision.zig");
const field_mapper = @import("../utils/field_mapper.zig");

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
const TradeType = @import("../models/trade.zig").TradeType;
const OHLCV = @import("../models/ohlcv.zig").OHLCV;
const types = @import("../base/types.zig");

/// Hyperliquid Exchange (DEX / Perpetuals)
/// Documentation: https://hyperliquid.gitbook.io/hyperliquid-docs/
/// 
/// Hyperliquid is a decentralized perpetuals exchange with unique field naming:
/// - Uses "px" for price fields (midPx, markPx, prevDayPx)
/// - Uses "sz" for size/amount fields
/// - WebSocket-based real-time data
/// - L2 orderbook with efficient updates
pub const Hyperliquid = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    wallet_address: ?[]const u8,
    wallet_private_key: ?[]const u8,
    testnet: bool,
    precision_config: precision_utils.ExchangePrecisionConfig,
    field_mapping: field_mapper.FieldMapping,

    const API_URL = "https://api.hyperliquid.xyz";
    const API_URL_TESTNET = "https://api.hyperliquid-testnet.xyz";
    const WS_URL = "wss://api.hyperliquid.xyz/ws";
    const WS_URL_TESTNET = "wss://api.hyperliquid-testnet.xyz/ws";

    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig, testnet: bool) !*Hyperliquid {
        const self = try allocator.create(Hyperliquid);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.wallet_address = auth_config.wallet_address;
        self.wallet_private_key = auth_config.wallet_private_key;
        self.testnet = testnet;
        self.precision_config = precision_utils.ExchangePrecisionConfig.dex();
        
        // Initialize field mapping for Hyperliquid
        self.field_mapping = try field_mapper.FieldMapperUtils.getFieldMapping(allocator, "hyperliquid");

        var http_client = try http.HttpClient.init(allocator);
        errdefer http_client.deinit();

        const base_name = try allocator.dupe(u8, "hyperliquid");
        const base_url = if (testnet) API_URL_TESTNET else API_URL;
        const base_url_copy = try allocator.dupe(u8, base_url);
        const ws_url = if (testnet) WS_URL_TESTNET else WS_URL;
        const ws_url_copy = try allocator.dupe(u8, ws_url);

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

        try self.base.headers.put(try allocator.dupe(u8, "User-Agent"), try allocator.dupe(u8, self.base.user_agent));
        try self.base.headers.put(try allocator.dupe(u8, "Accept"), try allocator.dupe(u8, "application/json"));
        try self.base.headers.put(try allocator.dupe(u8, "Content-Type"), try allocator.dupe(u8, "application/json"));

        return self;
    }

    pub fn deinit(self: *Hyperliquid) void {
        if (self.wallet_address) |w| self.allocator.free(w);
        if (self.wallet_private_key) |w| self.allocator.free(w);
        self.field_mapping.deinit();
        self.base.deinit();
        self.allocator.destroy(self);
    }

    /// Authenticate request with wallet signature (for private endpoints)
    fn authenticate(
        self: *Hyperliquid,
        request_body: []const u8,
    ) ![]const u8 {
        if (self.wallet_private_key == null) {
            return error.AuthenticationRequired;
        }
        
        // Hyperliquid uses EIP-712 style signatures
        // For simplicity, using HMAC-SHA256 signature
        const private_key = self.wallet_private_key.?;
        const signature = try crypto.Signer.hmacSha256Hex(self.allocator, private_key, request_body);
        return signature;
    }

    // ==================== Market Data ====================

    pub fn fetchMarkets(self: *Hyperliquid) ![]Market {
        if (self.base.isMarketsCacheValid()) {
            return self.base.markets.?;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/info", .{self.base.api_url});
        defer self.allocator.free(url);

        // Request metadata for all perpetuals
        const request_body = 
            \\{"type":"meta"}
        ;

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            headers.deinit();
        }
        try headers.put(try self.allocator.dupe(u8, "Content-Type"), "application/json");

        const response = try self.base.http_client.post(url, request_body, &headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        var markets = std.ArrayList(Market).init(self.allocator);
        defer markets.deinit();

        // Hyperliquid returns { "universe": [...markets...] }
        const universe = parsed.value.object.get("universe") orelse return error.InvalidResponse;

        switch (universe) {
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

    fn parseMarket(self: *Hyperliquid, json_val: std.json.Value) !Market {
        const parser = &self.base.json_parser;
        const mapper = &self.field_mapping;

        // Hyperliquid perpetual market format:
        // {"name": "BTC", "szDecimals": 5, ...}
        const name = field_mapper.FieldMapperUtils.getStringField(parser, json_val, "symbol", mapper, "");
        const sz_decimals = parser.getInt(json_val.object.get("szDecimals") orelse .{ .integer = 5 }, 5);
        
        const symbol = try std.fmt.allocPrint(self.allocator, "{s}/USD:USD", .{name});
        const base_copy = try self.allocator.dupe(u8, name);
        const quote_copy = try self.allocator.dupe(u8, "USD");
        const settle_copy = try self.allocator.dupe(u8, "USD");

        var limits = Market.MarketLimits{};
        var precision = Market.MarketPrecision{
            .amount = @intCast(sz_decimals),
            .price = 5, // Hyperliquid uses 5 decimal places for prices
        };

        return Market{
            .id = try self.allocator.dupe(u8, name),
            .symbol = symbol,
            .base = base_copy,
            .quote = quote_copy,
            .baseId = try self.allocator.dupe(u8, name),
            .quoteId = try self.allocator.dupe(u8, "USD"),
            .active = true,
            .spot = false,
            .margin = false,
            .future = false,
            .swap = true, // Perpetual swaps
            .option = false,
            .contract = true,
            .settle = settle_copy,
            .settleId = try self.allocator.dupe(u8, "USD"),
            .limits = limits,
            .precision = precision,
            .info = json_val,
        };
    }

    pub fn fetchTicker(self: *Hyperliquid, symbol: []const u8) !Ticker {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator, "{s}/info", .{self.base.api_url});
        defer self.allocator.free(url);

        // Request all mid prices
        const request_body = 
            \\{"type":"allMids"}
        ;

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            headers.deinit();
        }
        try headers.put(try self.allocator.dupe(u8, "Content-Type"), "application/json");

        const response = try self.base.http_client.post(url, request_body, &headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        // Response format: {"BTC": "50000.0", "ETH": "3000.0", ...}
        const price_str = parser.getString(parsed.value, market.base, "0") orelse "0";
        const price = try std.fmt.parseFloat(f64, price_str);

        return Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = time.TimeUtils.now(),
            .last = price,
            .info = parsed.value,
        };
    }

    pub fn fetchOrderBook(self: *Hyperliquid, symbol: []const u8, limit: ?u32) !OrderBook {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator, "{s}/info", .{self.base.api_url});
        defer self.allocator.free(url);

        // Request L2 orderbook
        const request_body = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"l2Book\",\"coin\":\"{s}\"}}",
            .{market.base}
        );
        defer self.allocator.free(request_body);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            headers.deinit();
        }
        try headers.put(try self.allocator.dupe(u8, "Content-Type"), "application/json");

        const response = try self.base.http_client.post(url, request_body, &headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        return try self.parseOrderBook(parsed.value, symbol, limit);
    }

    fn parseOrderBook(self: *Hyperliquid, json_val: std.json.Value, symbol: []const u8, limit: ?u32) !OrderBook {
        const parser = &self.base.json_parser;
        const mapper = &self.field_mapping;
        const timestamp = time.TimeUtils.now();

        // Hyperliquid L2 book format: {"levels": [[{"px": "50000", "sz": "1.5", "n": 1}, ...], [...]]}
        const levels = json_val.object.get("levels") orelse return error.InvalidResponse;
        
        var bids = std.ArrayList(OrderBook.OrderBookEntry).init(self.allocator);
        defer bids.deinit();
        
        var asks = std.ArrayList(OrderBook.OrderBookEntry).init(self.allocator);
        defer asks.deinit();

        switch (levels) {
            .array => |level_arr| {
                if (level_arr.items.len >= 2) {
                    // First array is bids
                    const bids_array = level_arr.items[0];
                    switch (bids_array) {
                        .array => |bid_arr| {
                            const max_bids = if (limit) |l| @min(bid_arr.items.len, l) else bid_arr.items.len;
                            for (0..max_bids) |i| {
                                const bid = bid_arr.items[i];
                                const price = field_mapper.FieldMapperUtils.getFloatField(parser, bid, "price", mapper, 0);
                                const size = field_mapper.FieldMapperUtils.getFloatField(parser, bid, "size", mapper, 0);
                                
                                try bids.append(OrderBook.OrderBookEntry{
                                    .price = price,
                                    .amount = size,
                                    .timestamp = timestamp,
                                });
                            }
                        },
                        else => {},
                    }

                    // Second array is asks
                    const asks_array = level_arr.items[1];
                    switch (asks_array) {
                        .array => |ask_arr| {
                            const max_asks = if (limit) |l| @min(ask_arr.items.len, l) else ask_arr.items.len;
                            for (0..max_asks) |i| {
                                const ask = ask_arr.items[i];
                                const price = field_mapper.FieldMapperUtils.getFloatField(parser, ask, "price", mapper, 0);
                                const size = field_mapper.FieldMapperUtils.getFloatField(parser, ask, "size", mapper, 0);
                                
                                try asks.append(OrderBook.OrderBookEntry{
                                    .price = price,
                                    .amount = size,
                                    .timestamp = timestamp,
                                });
                            }
                        },
                        else => {},
                    }
                }
            },
            else => return error.InvalidResponse,
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
        self: *Hyperliquid,
        symbol: []const u8,
        timeframe: []const u8,
        since: ?i64,
        limit: ?u32,
    ) ![]OHLCV {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator, "{s}/info", .{self.base.api_url});
        defer self.allocator.free(url);

        // Convert timeframe to Hyperliquid format (1m, 1h, 1d)
        const start_time = since orelse (time.TimeUtils.now() - 86400000); // Default: last 24h
        const end_time = time.TimeUtils.now();

        const request_body = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"candleSnapshot\",\"req\":{{\"coin\":\"{s}\",\"interval\":\"{s}\",\"startTime\":{d},\"endTime\":{d}}}}}",
            .{ market.base, timeframe, start_time, end_time }
        );
        defer self.allocator.free(request_body);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            headers.deinit();
        }
        try headers.put(try self.allocator.dupe(u8, "Content-Type"), "application/json");

        const response = try self.base.http_client.post(url, request_body, &headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        return try self.parseOHLCV(parsed.value, limit);
    }

    fn parseOHLCV(self: *Hyperliquid, json_val: std.json.Value, limit: ?u32) ![]OHLCV {
        const parser = &self.base.json_parser;

        var ohlcvs = std.ArrayList(OHLCV).init(self.allocator);
        defer ohlcvs.deinit();

        // Hyperliquid candle format: [{"t": timestamp, "T": close_time, "o": open, "h": high, "l": low, "c": close, "v": volume}, ...]
        switch (json_val) {
            .array => |arr| {
                const max_items = if (limit) |l| @min(arr.items.len, l) else arr.items.len;
                for (0..max_items) |i| {
                    const item = arr.items[i];
                    const timestamp = parser.getInt(item.object.get("t") orelse .{ .integer = 0 }, 0);
                    const open = parser.getFloat(item.object.get("o") orelse .{ .float = 0 }, 0);
                    const high = parser.getFloat(item.object.get("h") orelse .{ .float = 0 }, 0);
                    const low = parser.getFloat(item.object.get("l") orelse .{ .float = 0 }, 0);
                    const close = parser.getFloat(item.object.get("c") orelse .{ .float = 0 }, 0);
                    const volume = parser.getFloat(item.object.get("v") orelse .{ .float = 0 }, 0);

                    try ohlcvs.append(OHLCV{
                        .timestamp = timestamp,
                        .open = open,
                        .high = high,
                        .low = low,
                        .close = close,
                        .volume = volume,
                    });
                }
            },
            else => return error.InvalidResponse,
        }

        return try ohlcvs.toOwnedSlice();
    }

    pub fn fetchTrades(self: *Hyperliquid, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator, "{s}/info", .{self.base.api_url});
        defer self.allocator.free(url);

        const request_body = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"tradeHistory\",\"coin\":\"{s}\"}}",
            .{market.base}
        );
        defer self.allocator.free(request_body);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            headers.deinit();
        }
        try headers.put(try self.allocator.dupe(u8, "Content-Type"), "application/json");

        const response = try self.base.http_client.post(url, request_body, &headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        return try self.parseTrades(parsed.value, symbol, since, limit);
    }

    fn parseTrades(self: *Hyperliquid, json_val: std.json.Value, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        const parser = &self.base.json_parser;
        const mapper = &self.field_mapping;

        var trades = std.ArrayList(Trade).init(self.allocator);
        defer trades.deinit();

        // Hyperliquid trade format: [{"coin": "BTC", "px": "50000", "sz": "1.5", "side": "B", "time": 1234567890}, ...]
        switch (json_val) {
            .array => |arr| {
                for (arr.items) |item| {
                    const trade_time = field_mapper.FieldMapperUtils.getIntField(parser, item, "timestamp", mapper, 0);
                    
                    // Filter by since timestamp if provided
                    if (since) |s| {
                        if (trade_time < s) continue;
                    }
                    
                    const trade = try self.parseTrade(item, symbol);
                    try trades.append(trade);
                    
                    // Check limit
                    if (limit) |l| {
                        if (trades.items.len >= l) break;
                    }
                }
            },
            else => return error.InvalidResponse,
        }

        return try trades.toOwnedSlice();
    }

    fn parseTrade(self: *Hyperliquid, json_val: std.json.Value, symbol: []const u8) !Trade {
        const parser = &self.base.json_parser;
        const mapper = &self.field_mapping;

        const price = field_mapper.FieldMapperUtils.getFloatField(parser, json_val, "price", mapper, 0);
        const size = field_mapper.FieldMapperUtils.getFloatField(parser, json_val, "size", mapper, 0);
        const timestamp = field_mapper.FieldMapperUtils.getIntField(parser, json_val, "timestamp", mapper, time.TimeUtils.now());
        
        const side_str = parser.getString(json_val, "side", "") orelse "";
        const is_buy = std.mem.eql(u8, side_str, "B") or std.mem.eql(u8, side_str, "buy");

        const tid = parser.getInt(json_val.object.get("tid") orelse .{ .integer = 0 }, 0);
        const id_str = try std.fmt.allocPrint(self.allocator, "{d}", .{tid});

        return Trade{
            .id = id_str,
            .timestamp = timestamp,
            .datetime = try self.base.parseDatetime(self.allocator, timestamp),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = .swap,
            .side = if (is_buy) try self.allocator.dupe(u8, "buy") else try self.allocator.dupe(u8, "sell"),
            .price = price,
            .amount = size,
            .cost = price * size,
            .info = json_val,
        };
    }

    // ==================== Private Methods ====================

    pub fn fetchBalance(self: *Hyperliquid) ![]Balance {
        if (self.wallet_address == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/info", .{self.base.api_url});
        defer self.allocator.free(url);

        const request_body = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"clearinghouseState\",\"user\":\"{s}\"}}",
            .{self.wallet_address.?}
        );
        defer self.allocator.free(request_body);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            headers.deinit();
        }
        try headers.put(try self.allocator.dupe(u8, "Content-Type"), "application/json");

        const response = try self.base.http_client.post(url, request_body, &headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        return try self.parseBalance(parsed.value);
    }

    fn parseBalance(self: *Hyperliquid, json_val: std.json.Value) ![]Balance {
        const parser = &self.base.json_parser;
        var balances = std.ArrayList(Balance).init(self.allocator);
        defer balances.deinit();

        // Hyperliquid balance format: {"marginSummary": {"accountValue": "10000", "totalMarginUsed": "1000", ...}}
        const margin_summary = json_val.object.get("marginSummary") orelse return error.InvalidResponse;
        
        const account_value = parser.getFloat(margin_summary.object.get("accountValue") orelse .{ .float = 0 }, 0);
        const margin_used = parser.getFloat(margin_summary.object.get("totalMarginUsed") orelse .{ .float = 0 }, 0);
        
        const total = types.Decimal{
            .value = @as(i128, @intFromFloat(@round(account_value * 100_000_000))),
            .scale = 8,
        };
        const used = types.Decimal{
            .value = @as(i128, @intFromFloat(@round(margin_used * 100_000_000))),
            .scale = 8,
        };
        const free = types.Decimal{
            .value = @as(i128, @intFromFloat(@round((account_value - margin_used) * 100_000_000))),
            .scale = 8,
        };

        try balances.append(Balance{
            .currency = try self.allocator.dupe(u8, "USD"),
            .free = free,
            .used = used,
            .total = total,
            .timestamp = time.TimeUtils.now(),
            .info = json_val,
        });

        return try balances.toOwnedSlice();
    }

    pub fn createOrder(
        self: *Hyperliquid,
        symbol: []const u8,
        order_type: OrderType,
        side: OrderSide,
        amount: f64,
        price: ?f64,
        params: ?std.StringHashMap([]const u8),
    ) !Order {
        if (self.wallet_address == null or self.wallet_private_key == null) {
            return error.AuthenticationRequired;
        }

        const market = self.base.findMarket(symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator, "{s}/exchange", .{self.base.api_url});
        defer self.allocator.free(url);

        const is_buy = side == .buy;
        const limit_px = if (order_type == .market) null else price;
        const order_type_str = if (order_type == .limit) "limit" else "market";

        // Build order request
        var order_json = std.ArrayList(u8).init(self.allocator);
        defer order_json.deinit();
        
        const writer = order_json.writer();
        try writer.print(
            "{{\"type\":\"order\",\"orders\":[{{\"coin\":\"{s}\",\"is_buy\":{},\"sz\":{d},\"limit_px\":",
            .{ market.base, is_buy, amount }
        );
        
        if (limit_px) |px| {
            try writer.print("{d}", .{px});
        } else {
            try writer.writeAll("null");
        }
        
        try writer.print(",\"order_type\":{{\"limit\":{{\"tif\":\"{s}\"}}}}}}", .{order_type_str});
        try writer.writeAll("],\"signature\":\"\"}}"); // Signature would be added here in production

        const request_body = try order_json.toOwnedSlice();
        defer self.allocator.free(request_body);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            headers.deinit();
        }
        try headers.put(try self.allocator.dupe(u8, "Content-Type"), "application/json");

        const response = try self.base.http_client.post(url, request_body, &headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        return try self.parseOrder(parsed.value, symbol);
    }

    fn parseOrder(self: *Hyperliquid, json_val: std.json.Value, symbol: []const u8) !Order {
        const parser = &self.base.json_parser;
        const mapper = &self.field_mapping;

        const order_id = parser.getString(json_val, "oid", "0") orelse "0";
        const status_str = parser.getString(json_val, "status", "open") orelse "open";
        
        const status = if (std.mem.eql(u8, status_str, "filled"))
            OrderStatus.closed
        else if (std.mem.eql(u8, status_str, "canceled"))
            OrderStatus.canceled
        else
            OrderStatus.open;

        const price = field_mapper.FieldMapperUtils.getFloatField(parser, json_val, "price", mapper, 0);
        const size = field_mapper.FieldMapperUtils.getFloatField(parser, json_val, "size", mapper, 0);
        const filled = parser.getFloat(json_val.object.get("filled") orelse .{ .float = 0 }, 0);
        
        const side_str = parser.getString(json_val, "side", "buy") orelse "buy";
        const side = if (std.mem.eql(u8, side_str, "B") or std.mem.eql(u8, side_str, "buy"))
            OrderSide.buy
        else
            OrderSide.sell;

        const timestamp = time.TimeUtils.now();

        return Order{
            .id = try self.allocator.dupe(u8, order_id),
            .timestamp = timestamp,
            .datetime = try self.base.parseDatetime(self.allocator, timestamp),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = .limit,
            .side = side,
            .price = price,
            .amount = size,
            .filled = filled,
            .remaining = size - filled,
            .cost = price * filled,
            .status = status,
            .info = json_val,
        };
    }

    pub fn cancelOrder(self: *Hyperliquid, order_id: []const u8, symbol: ?[]const u8) !void {
        if (self.wallet_address == null or self.wallet_private_key == null) {
            return error.AuthenticationRequired;
        }

        const market_symbol = symbol orelse return error.SymbolRequired;
        const market = self.base.findMarket(market_symbol) orelse
            return error.SymbolNotFound;

        const url = try std.fmt.allocPrint(self.allocator, "{s}/exchange", .{self.base.api_url});
        defer self.allocator.free(url);

        const request_body = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"cancel\",\"cancels\":[{{\"coin\":\"{s}\",\"oid\":{s}}}],\"signature\":\"\"}}",
            .{ market.base, order_id }
        );
        defer self.allocator.free(request_body);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            headers.deinit();
        }
        try headers.put(try self.allocator.dupe(u8, "Content-Type"), "application/json");

        const response = try self.base.http_client.post(url, request_body, &headers);
        defer response.deinit(self.allocator);

        // Check response status
        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        const status = parser.getString(parsed.value, "status", "") orelse "";
        if (!std.mem.eql(u8, status, "ok") and !std.mem.eql(u8, status, "success")) {
            return error.CancelOrderFailed;
        }
    }

    pub fn fetchOrder(self: *Hyperliquid, order_id: []const u8, symbol: ?[]const u8) !Order {
        _ = order_id;
        
        if (self.wallet_address == null) {
            return error.AuthenticationRequired;
        }

        // Hyperliquid doesn't have a direct fetchOrder endpoint
        // We need to fetch all open orders and find the matching one
        const orders = try self.fetchOpenOrders(symbol);
        defer self.allocator.free(orders);
        defer for (orders) |*order| order.deinit(self.allocator);

        for (orders) |order| {
            if (std.mem.eql(u8, order.id, order_id)) {
                return order;
            }
        }

        return error.OrderNotFound;
    }

    pub fn fetchOpenOrders(self: *Hyperliquid, symbol: ?[]const u8) ![]Order {
        if (self.wallet_address == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/info", .{self.base.api_url});
        defer self.allocator.free(url);

        const request_body = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"openOrders\",\"user\":\"{s}\"}}",
            .{self.wallet_address.?}
        );
        defer self.allocator.free(request_body);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            headers.deinit();
        }
        try headers.put(try self.allocator.dupe(u8, "Content-Type"), "application/json");

        const response = try self.base.http_client.post(url, request_body, &headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        return try self.parseOrders(parsed.value, symbol);
    }

    pub fn fetchClosedOrders(self: *Hyperliquid, symbol: ?[]const u8, since: ?i64, limit: ?u32) ![]Order {
        if (self.wallet_address == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/info", .{self.base.api_url});
        defer self.allocator.free(url);

        const request_body = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"userFills\",\"user\":\"{s}\"}}",
            .{self.wallet_address.?}
        );
        defer self.allocator.free(request_body);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            headers.deinit();
        }
        try headers.put(try self.allocator.dupe(u8, "Content-Type"), "application/json");

        const response = try self.base.http_client.post(url, request_body, &headers);
        defer response.deinit(self.allocator);

        const parser = &self.base.json_parser;
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        return try self.parseOrders(parsed.value, symbol);
    }

    fn parseOrders(self: *Hyperliquid, json_val: std.json.Value, filter_symbol: ?[]const u8) ![]Order {
        var orders = std.ArrayList(Order).init(self.allocator);
        defer orders.deinit();

        switch (json_val) {
            .array => |arr| {
                for (arr.items) |item| {
                    const order = try self.parseOrder(item, filter_symbol orelse "");
                    
                    // Filter by symbol if provided
                    if (filter_symbol) |sym| {
                        if (!std.mem.eql(u8, order.symbol, sym)) {
                            order.deinit(self.allocator);
                            continue;
                        }
                    }
                    
                    try orders.append(order);
                }
            },
            else => return error.InvalidResponse,
        }

        return try orders.toOwnedSlice();
    }
};

pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*Hyperliquid {
    return Hyperliquid.init(allocator, auth_config, false);
}

pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*Hyperliquid {
    return Hyperliquid.init(allocator, auth_config, true);
}
