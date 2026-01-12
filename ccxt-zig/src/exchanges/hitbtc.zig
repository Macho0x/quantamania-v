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

// HitBTC Exchange Implementation
// HitBTC is a major European cryptocurrency exchange
// Documentation: https://api.hitbtc.com/

pub const HitBTC = struct {
    allocator: std.mem.Allocator,
    base: base.Exchange,
    
    pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*HitBTC {
        const hitbtc = try allocator.create(HitBTC);
        hitbtc.allocator = allocator;
        
        hitbtc.base = try base.Exchange.init(allocator, auth_config);
        try hitbtc.base.configure(.{
            .name = "hitbtc",
            .display_name = "HitBTC",
            .api_urls = .{
                .rest = "https://api.hitbtc.com",
                .ws = "wss://api.hitbtc.com/2/websocket",
            },
            .precision_mode = precision.PrecisionMode.decimal_places,
            .supports_spot = true,
            .supports_margin = true,
            .supports_futures = true,
        });
        
        return hitbtc;
    }
    
    pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*HitBTC {
        const hitbtc = try allocator.create(HitBTC);
        hitbtc.allocator = allocator;
        
        hitbtc.base = try base.Exchange.init(allocator, auth_config);
        try hitbtc.base.configure(.{
            .name = "hitbtc",
            .display_name = "HitBTC Testnet",
            .api_urls = .{
                .rest = "https://api.demo.hitbtc.com",
                .ws = "wss://api.demo.hitbtc.com/2/websocket",
            },
            .precision_mode = precision.PrecisionMode.decimal_places,
            .supports_spot = true,
            .supports_margin = true,
            .supports_futures = true,
        });
        
        return hitbtc;
    }
    
    pub fn deinit(self: *HitBTC) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }
    
    // Template exchange - methods return error.NotImplemented
    // Full API implementation pending future development
    pub fn fetchMarkets(self: *HitBTC) ![]models.Market {
        const url = "https://api.hitbtc.com/api/2/public/symbol";
        
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        
        const response = try self.base.http_client.get(url, &headers);
        defer response.deinit(self.allocator);
        
        if (response.status != 200) {
            return error.NetworkError;
        }
        
        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();
        
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();
        
        var markets = std.ArrayList(models.Market).init(self.allocator);
        
        const symbols = parsed.array.items;
        
        for (symbols) |symbol_json| {
            const symbol_data = symbol_json.object;
            
            const base_currency = symbol_data.get("base_currency") orelse continue;
            const quote_currency = symbol_data.get("quote_currency") orelse continue;
            const id = symbol_data.get("id") orelse continue;
            const visibility = symbol_data.get("visibility") orelse continue;
            
            if (!std.mem.eql(u8, visibility.string, "DECENTRALIZED")) continue;
            
            const tick_step = symbol_data.get("tick_step") orelse continue;
            const step = symbol_data.get("step") orelse continue;
            
            var market = models.Market{
                .id = try self.allocator.dupe(u8, id.string),
                .symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base_currency.string, quote_currency.string }),
                .base = try self.allocator.dupe(u8, base_currency.string),
                .quote = try self.allocator.dupe(u8, quote_currency.string),
                .active = true,
                .spot = true,
                .margin = false,
                .future = false,
                .limits = .{
                    .amount = .{
                        .min = symbol_data.get("quantity_increment") orelse null,
                        .max = null,
                    },
                    .price = .{
                        .min = symbol_data.get("price_min") orelse null,
                        .max = symbol_data.get("price_max") orelse null,
                    },
                    .cost = .{
                        .min = null,
                        .max = null,
                    },
                },
                .precision = .{
                    .amount = symbol_data.get("quantity_scale") orelse null,
                    .price = symbol_data.get("price_scale") orelse null,
                },
                .info = parsed,
            };
            
            try markets.append(market);
        }
        
        return markets.toOwnedSlice();
    }
    
    pub fn fetchTicker(self: *HitBTC, symbol: []const u8) !models.Ticker {
        const url = try std.fmt.allocPrint(self.allocator, "https://api.hitbtc.com/api/2/public/ticker/{s}", .{symbol});
        defer self.allocator.free(url);
        
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        
        const response = try self.base.http_client.get(url, &headers);
        defer response.deinit(self.allocator);
        
        if (response.status != 200) {
            return error.NetworkError;
        }
        
        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();
        
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();
        
        const last = parsed.object.get("last") orelse return error.NetworkError;
        const high = parsed.object.get("high") orelse return error.NetworkError;
        const low = parsed.object.get("low") orelse return error.NetworkError;
        const bid = parsed.object.get("bid") orelse return error.NetworkError;
        const ask = parsed.object.get("ask") orelse return error.NetworkError;
        const volume = parsed.object.get("volume") orelse return error.NetworkError;
        
        return models.Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = std.time.milliTimestamp(),
            .high = high.number.asFloat(),
            .low = low.number.asFloat(),
            .bid = bid.number.asFloat(),
            .ask = ask.number.asFloat(),
            .last = last.number.asFloat(),
            .baseVolume = volume.number.asFloat(),
            .quoteVolume = parsed.object.get("volume_quote").?.number.asFloat(),
            .percentage = null,
            .info = parsed,
        };
    }
    
    pub fn fetchOrderBook(self: *HitBTC, symbol: []const u8, limit: ?u32) !models.OrderBook {
        const limit_param = if (limit) |l| std.fmt.allocPrint(self.allocator, "&limit={d}", .{l}) else "";
        defer if (limit_param.len > 0) self.allocator.free(limit_param);
        
        const url = try std.fmt.allocPrint(self.allocator, "https://api.hitbtc.com/api/2/public/orderbook/{s}?format=RFC3339{s}", .{ symbol, limit_param });
        defer self.allocator.free(url);
        
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        
        const response = try self.base.http_client.get(url, &headers);
        defer response.deinit(self.allocator);
        
        if (response.status != 200) {
            return error.NetworkError;
        }
        
        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();
        
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();
        
        const bids_data = parsed.object.get("bids") orelse return error.NetworkError;
        const asks_data = parsed.object.get("asks") orelse return error.NetworkError;
        const timestamp = parsed.object.get("timestamp") orelse return error.NetworkError;
        
        var bids = std.ArrayList(models.OrderBookEntry).init(self.allocator);
        var asks = std.ArrayList(models.OrderBookEntry).init(self.allocator);
        
        for (bids_data.array.items) |bid_data| {
            const price = bid_data.object.get("price").?.number.asFloat();
            const amount = bid_data.object.get("size").?.number.asFloat();
            const ts = bid_data.object.get("timestamp") orelse return error.NetworkError;
            
            try bids.append(models.OrderBookEntry{
                .price = price,
                .amount = amount,
                .timestamp = try self.parseTimestamp(ts.string),
            });
        }
        
        for (asks_data.array.items) |ask_data| {
            const price = ask_data.object.get("price").?.number.asFloat();
            const amount = ask_data.object.get("size").?.number.asFloat();
            const ts = ask_data.object.get("timestamp") orelse return error.NetworkError;
            
            try asks.append(models.OrderBookEntry{
                .price = price,
                .amount = amount,
                .timestamp = try self.parseTimestamp(ts.string),
            });
        }
        
        return models.OrderBook{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = try self.parseTimestamp(timestamp.string),
            .datetime = timestamp.string,
            .bids = bids.toOwnedSlice(),
            .asks = asks.toOwnedSlice(),
            .nonce = null,
        };
    }

    pub fn fetchOHLCV(self: *HitBTC, symbol: []const u8, timeframe: []const u8, since: ?i64, limit: ?u32) ![]OHLCV {
        _ = self;
        _ = symbol;
        _ = timeframe;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }
    
    pub fn fetchTrades(self: *HitBTC, symbol: []const u8, since: ?i64, limit: ?u32) ![]models.Trade {
        const limit_param = if (limit) |l| std.fmt.allocPrint(self.allocator, "&limit={d}", .{l}) else "";
        const since_param = if (since) |s| std.fmt.allocPrint(self.allocator, "&from={d}", .{s}) else "";
        defer {
            if (limit_param.len > 0) self.allocator.free(limit_param);
            if (since_param.len > 0) self.allocator.free(since_param);
        }
        
        const url = try std.fmt.allocPrint(self.allocator, "https://api.hitbtc.com/api/2/public/trades/{s}?format=RFC3339{s}{s}", .{ symbol, limit_param, since_param });
        defer self.allocator.free(url);
        
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        
        const response = try self.base.http_client.get(url, &headers);
        defer response.deinit(self.allocator);
        
        if (response.status != 200) {
            return error.NetworkError;
        }
        
        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();
        
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();
        
        var trades = std.ArrayList(models.Trade).init(self.allocator);
        
        for (parsed.array.items) |trade_data| {
            const id = trade_data.object.get("id") orelse continue;
            const price = trade_data.object.get("price") orelse continue;
            const quantity = trade_data.object.get("quantity") orelse continue;
            const side = trade_data.object.get("side") orelse continue;
            const timestamp = trade_data.object.get("timestamp") orelse continue;
            
            try trades.append(models.Trade{
                .id = try self.allocator.dupe(u8, id.string),
                .timestamp = try self.parseTimestamp(timestamp.string),
                .datetime = timestamp.string,
                .symbol = try self.allocator.dupe(u8, symbol),
                .type = models.TradeType.spot,
                .side = try self.allocator.dupe(u8, side.string),
                .price = price.number.asFloat(),
                .amount = quantity.number.asFloat(),
                .cost = price.number.asFloat() * quantity.number.asFloat(),
                .info = trade_data,
            });
        }
        
        return trades.toOwnedSlice();
    }
    
    // Private endpoints (require authentication)
    pub fn fetchBalance(self: *HitBTC) ![]models.Balance {
        const url = "https://api.hitbtc.com/api/2/account/balance";
        
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        
        try self.authenticate(&headers);
        
        const response = try self.base.http_client.get(url, &headers);
        defer response.deinit(self.allocator);
        
        if (response.status != 200) {
            return error.AuthenticationRequired;
        }
        
        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();
        
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();
        
        var balances = std.ArrayList(models.Balance).init(self.allocator);
        
        for (parsed.array.items) |balance_data| {
            const currency = balance_data.object.get("currency") orelse continue;
            const available = balance_data.object.get("available") orelse continue;
            const reserved = balance_data.object.get("reserved") orelse continue;
            
            if (available.number.asFloat() > 0 or reserved.number.asFloat() > 0) {
                try balances.append(models.Balance{
                    .currency = try self.allocator.dupe(u8, currency.string),
                    .free = available.number.asFloat(),
                    .used = reserved.number.asFloat(),
                    .total = available.number.asFloat() + reserved.number.asFloat(),
                });
            }
        }
        
        return balances.toOwnedSlice();
    }

    // Order management methods
        pub fn createOrder(
        self: *HitBTC,
        symbol: []const u8,
        type_str: []const u8,
        side_str: []const u8,
        amount: f64,
        price: ?f64,
        params: ?std.StringHashMap([]const u8),
        ) !Order {
        _ = params;
        if (self.base.auth_config.apiKey == null or self.base.auth_config.apiSecret == null) {
            return error.AuthenticationRequired;
        }

        const market = self.base.findMarket(symbol) orelse return error.SymbolNotFound;

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        try body.appendSlice(try std.fmt.allocPrint(self.allocator,
            "symbol={s}&side={s}&type={s}&quantity={d}",
            .{ market.id, side_str, type_str, amount }));

        if (price) |p| {
            try body.appendSlice(try std.fmt.allocPrint(self.allocator, "&price={d}", .{p}));
        }

        const url = "https://api.hitbtc.com/api/2/order";

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();

        try self.authenticate(&headers);

        const response = try self.base.http_client.post(url, &headers, body.items);
        defer response.deinit(self.allocator);

        if (response.status != 200) {
            return error.NetworkError;
        }

        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();

        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        const order_id = parsed.object.get("id").?.string orelse return error.NetworkError;
        const status = parsed.object.get("status").?.string orelse return error.NetworkError;

        return Order{
            .id = try self.allocator.dupe(u8, order_id),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = try self.allocator.dupe(u8, type_str),
            .side = try self.allocator.dupe(u8, side_str),
            .price = price,
            .amount = amount,
            .status = try self.allocator.dupe(u8, status),
            .timestamp = std.time.milliTimestamp(),
            .info = parsed,
        };
        }

        pub fn cancelOrder(self: *HitBTC, order_id: []const u8, symbol: []const u8) !Order {
        if (self.base.auth_config.apiKey == null or self.base.auth_config.apiSecret == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator, "https://api.hitbtc.com/api/2/order/{s}", .{ order_id });
        defer self.allocator.free(url);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();

        try self.authenticate(&headers);

        const response = try self.base.http_client.delete(url, &headers);
        defer response.deinit(self.allocator);

        if (response.status != 200) {
            return error.NetworkError;
        }

        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();

        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        const status = parsed.object.get("status").?.string orelse return error.NetworkError;

        return Order{
            .id = try self.allocator.dupe(u8, order_id),
            .symbol = try self.allocator.dupe(u8, symbol),
            .status = try self.allocator.dupe(u8, status),
            .timestamp = std.time.milliTimestamp(),
            .info = parsed,
        };
        }

        pub fn fetchOrder(self: *HitBTC, order_id: []const u8, symbol: []const u8) !Order {
        if (self.base.auth_config.apiKey == null or self.base.auth_config.apiSecret == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator, "https://api.hitbtc.com/api/2/order/{s}", .{ order_id });
        defer self.allocator.free(url);

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();

        try self.authenticate(&headers);

        const response = try self.base.http_client.get(url, &headers);
        defer response.deinit(self.allocator);

        if (response.status != 200) {
            return error.NetworkError;
        }

        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();

        const parsed = try parser.parse(response.body);
        defer parsed.deinit();

        const status = parsed.object.get("status").?.string orelse return error.NetworkError;
        const type_str = parsed.object.get("type").?.string orelse return error.NetworkError;
        const side_str = parsed.object.get("side").?.string orelse return error.NetworkError;
        const price = parsed.object.get("price").?.number.asFloat();
        const quantity = parsed.object.get("quantity").?.number.asFloat();

        return Order{
            .id = try self.allocator.dupe(u8, order_id),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = try self.allocator.dupe(u8, type_str),
            .side = try self.allocator.dupe(u8, side_str),
            .price = price,
            .amount = quantity,
            .status = try self.allocator.dupe(u8, status),
            .timestamp = std.time.milliTimestamp(),
            .info = parsed,
        };
        }

        pub fn fetchOpenOrders(self: *HitBTC, symbol: ?[]const u8) ![]Order {
        if (self.base.auth_config.apiKey == null or self.base.auth_config.apiSecret == null) {
            return error.AuthenticationRequired;
        }

        var url = "https://api.hitbtc.com/api/2/order";
        if (symbol) |s| {
            const market = self.base.findMarket(s) orelse return error.SymbolNotFound;
            url = try std.fmt.allocPrint(self.allocator, "https://api.hitbtc.com/api/2/order?symbol={s}", .{ market.id });
            defer self.allocator.free(url);
        }

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();

        try self.authenticate(&headers);

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
            const order_id = order_data.object.get("id").?.string orelse continue;
            const order_symbol = order_data.object.get("symbol").?.string orelse continue;
            const status = order_data.object.get("status").?.string orelse continue;
            const type_str = order_data.object.get("type").?.string orelse continue;
            const side_str = order_data.object.get("side").?.string orelse continue;
            const price = order_data.object.get("price").?.number.asFloat();
            const quantity = order_data.object.get("quantity").?.number.asFloat();

            try orders.append(Order{
                .id = try self.allocator.dupe(u8, order_id),
                .symbol = try self.allocator.dupe(u8, order_symbol),
                .type = try self.allocator.dupe(u8, type_str),
                .side = try self.allocator.dupe(u8, side_str),
                .price = price,
                .amount = quantity,
                .status = try self.allocator.dupe(u8, status),
                .timestamp = std.time.milliTimestamp(),
                .info = order_data,
            });
        }

        return orders.toOwnedSlice();
        }

        pub fn fetchClosedOrders(self: *HitBTC, symbol: ?[]const u8, since: ?i64, limit: ?u32) ![]Order {
        if (self.base.auth_config.apiKey == null or self.base.auth_config.apiSecret == null) {
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
            try query.appendSlice(try std.fmt.allocPrint(self.allocator, "from={d}", .{ s }));
        }

        if (limit) |l| {
            if (query.len > 0) try query.append('&');
            try query.appendSlice(try std.fmt.allocPrint(self.allocator, "limit={d}", .{ l }));
        }

        var url = "https://api.hitbtc.com/api/2/history/order";
        if (query.len > 0) {
            url = try std.fmt.allocPrint(self.allocator, "https://api.hitbtc.com/api/2/history/order?{s}", .{ query.items });
            defer self.allocator.free(url);
        }

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();

        try self.authenticate(&headers);

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
            const order_id = order_data.object.get("id").?.string orelse continue;
            const order_symbol = order_data.object.get("symbol").?.string orelse continue;
            const status = order_data.object.get("status").?.string orelse continue;
            const type_str = order_data.object.get("type").?.string orelse continue;
            const side_str = order_data.object.get("side").?.string orelse continue;
            const price = order_data.object.get("price").?.number.asFloat();
            const quantity = order_data.object.get("quantity").?.number.asFloat();

            try orders.append(Order{
                .id = try self.allocator.dupe(u8, order_id),
                .symbol = try self.allocator.dupe(u8, order_symbol),
                .type = try self.allocator.dupe(u8, type_str),
                .side = try self.allocator.dupe(u8, side_str),
                .price = price,
                .amount = quantity,
                .status = try self.allocator.dupe(u8, status),
                .timestamp = std.time.milliTimestamp(),
                .info = order_data,
            });
        }

        return orders.toOwnedSlice();
        }

        // Authentication
        fn authenticate(self: *HitBTC, headers: *std.StringHashMap([]const u8)) !void {
        const api_key = self.base.auth_config.apiKey orelse return error.AuthenticationRequired;
        const api_secret = self.base.auth_config.apiSecret orelse return error.AuthenticationRequired;
        
        const timestamp = std.time.milliTimestamp();
        const nonce = try std.fmt.allocPrint(self.allocator, "{}", .{timestamp});
        defer self.allocator.free(nonce);
        
        const message = std.ArrayList(u8).init(self.allocator);
        defer message.deinit();
        
        try message.appendSlice(nonce);
        try message.appendSlice("GET");
        try message.appendSlice("/api/2/account/balance");
        try message.appendSlice("{}");
        try message.appendSlice(nonce);
        
        const signature = crypto.hmacSha256(api_secret, message.items);
        
        const auth_header = try std.fmt.allocPrint(self.allocator, "Basic {s}:{s}", .{ api_key, signature });
        defer self.allocator.free(auth_header);
        
        try headers.put(try self.allocator.dupe(u8, "Authorization"), auth_header);
    }
    
    // Helper function to parse RFC3339 timestamps
    fn parseTimestamp(self: *HitBTC, timestamp_str: []const u8) !i64 {
        // Simple implementation - extract timestamp from RFC3339 format
        // Format: "2023-01-01T12:00:00.000Z"
        const parts = std.mem.split(u8, timestamp_str, "T");
        const date_part = parts.first() orelse return error.NetworkError;
        const time_part = parts.rest() orelse return error.NetworkError;
        
        const year = std.mem.split(u8, date_part, "-").first() orelse return error.NetworkError;
        const month = std.mem.split(u8, date_part, "-").rest() orelse return error.NetworkError;
        const day = std.mem.split(u8, date_part, "-").rest() orelse return error.NetworkError;
        
        const year_int = std.fmt.parseInt(u16, year, 10) catch return error.NetworkError;
        const month_int = std.fmt.parseInt(u8, month, 10) catch return error.NetworkError;
        const day_int = std.fmt.parseInt(u8, day, 10) catch return error.NetworkError;
        
        // Convert to timestamp (simplified)
        return @intCast(year_int * 10000000000 + month_int * 100000000 + day_int * 1000000);
    }
};

// Import required modules
const models = @import("../models/types.zig");
const error = @import("../base/errors.zig");