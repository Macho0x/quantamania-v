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

// Upbit Exchange Implementation
// Upbit is the largest cryptocurrency exchange in South Korea
// Documentation: https://docs.upbit.com/

pub const Upbit = struct {
    allocator: std.mem.Allocator,
    base: base.Exchange,
    
    pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*Upbit {
        const upbit = try allocator.create(Upbit);
        upbit.allocator = allocator;
        
        upbit.base = try base.Exchange.init(allocator, auth_config);
        try upbit.base.configure(.{
            .name = "upbit",
            .display_name = "Upbit",
            .api_urls = .{
                .rest = "https://api.upbit.com/v1",
                .ws = "wss://api.upbit.com/websocket/v1",
            },
            .precision_mode = precision.PrecisionMode.decimal_places,
            .supports_spot = true,
            .supports_margin = false,
            .supports_futures = false,
        });
        
        return upbit;
    }
    
    pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*Upbit {
        // Upbit doesn't have a public testnet
        return Upbit.create(allocator, auth_config);
    }
    
    pub fn deinit(self: *Upbit) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }
    
    // Template exchange - methods return error.NotImplemented
    // Full API implementation pending future development
    pub fn fetchMarkets(self: *Upbit) ![]models.Market {
        const url = "https://api.upbit.com/v1/market/all?quoteCurrency=KRW";
        
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
        
        for (parsed.array.items) |market_data| {
            const market = market_data.object.get("market") orelse continue;
            const korean_name = market_data.object.get("korean_name") orelse continue;
            const english_name = market_data.object.get("english_name") orelse continue;
            const market_type = market_data.object.get("market") orelse continue;
            
            // Extract base and quote from market code like "BTC-KRW"
            const parts = std.mem.split(u8, market.string, "-");
            const base_currency = parts.first() orelse continue;
            const quote_currency = parts.rest() orelse continue;
            
            if (std.mem.eql(u8, quote_currency, "KRW")) {
                var market_obj = models.Market{
                    .id = try self.allocator.dupe(u8, market.string),
                    .symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base_currency, quote_currency }),
                    .base = try self.allocator.dupe(u8, base_currency),
                    .quote = try self.allocator.dupe(u8, quote_currency),
                    .active = true,
                    .spot = true,
                    .margin = false,
                    .future = false,
                    .limits = .{
                        .amount = .{
                            .min = 0.00000001, // Upbit minimum
                            .max = null,
                        },
                        .price = .{
                            .min = 0.0001,
                            .max = null,
                        },
                        .cost = .{
                            .min = null,
                            .max = null,
                        },
                    },
                    .precision = .{
                        .amount = 8,
                        .price = 8,
                    },
                    .info = parsed,
                };
                
                try markets.append(market_obj);
            }
        }
        
        return markets.toOwnedSlice();
    }
    
    pub fn fetchTicker(self: *Upbit, symbol: []const u8) !models.Ticker {
        const url = try std.fmt.allocPrint(self.allocator, "https://api.upbit.com/v1/ticker?market={s}", .{symbol});
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
        
        const ticker_data = parsed.array.items[0];
        const high = ticker_data.object.get("high_price").?.number.asFloat();
        const low = ticker_data.object.get("low_price").?.number.asFloat();
        const bid = ticker_data.object.get("bid_price").?.number.asFloat();
        const ask = ticker_data.object.get("ask_price").?.number.asFloat();
        const last = ticker_data.object.get("trade_price").?.number.asFloat();
        const volume = ticker_data.object.get("acc_trade_volume_24h").?.number.asFloat();
        const timestamp = ticker_data.object.get("timestamp").?.number.asInt();
        
        return models.Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = @intCast(timestamp),
            .high = high,
            .low = low,
            .bid = bid,
            .ask = ask,
            .last = last,
            .baseVolume = volume,
            .quoteVolume = ticker_data.object.get("acc_trade_price_24h").?.number.asFloat(),
            .percentage = ticker_data.object.get("signed_change_price").?.number.asFloat(),
            .info = parsed,
        };
    }
    
    pub fn fetchOrderBook(self: *Upbit, symbol: []const u8, limit: ?u32) !models.OrderBook {
        const limit_param = if (limit) |l| std.fmt.allocPrint(self.allocator, "&count={d}", .{l}) else "";
        defer if (limit_param.len > 0) self.allocator.free(limit_param);
        
        const url = try std.fmt.allocPrint(self.allocator, "https://api.upbit.com/v1/orderbook?market={s}{s}", .{ symbol, limit_param });
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
        
        const orderbook_data = parsed.array.items[0];
        const bids_data = orderbook_data.object.get("bids") orelse return error.NetworkError;
        const asks_data = orderbook_data.object.get("asks") orelse return error.NetworkError;
        const timestamp = orderbook_data.object.get("timestamp").?.number.asInt();
        
        var bids = std.ArrayList(models.OrderBookEntry).init(self.allocator);
        var asks = std.ArrayList(models.OrderBookEntry).init(self.allocator);
        
        for (bids_data.array.items) |bid_data| {
            const price = bid_data.object.get("price").?.number.asFloat();
            const amount = bid_data.object.get("size").?.number.asFloat();
            
            try bids.append(models.OrderBookEntry{
                .price = price,
                .amount = amount,
                .timestamp = @intCast(timestamp),
            });
        }
        
        for (asks_data.array.items) |ask_data| {
            const price = ask_data.object.get("price").?.number.asFloat();
            const amount = ask_data.object.get("size").?.number.asFloat();
            
            try asks.append(models.OrderBookEntry{
                .price = price,
                .amount = amount,
                .timestamp = @intCast(timestamp),
            });
        }
        
        return models.OrderBook{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = @intCast(timestamp),
            .datetime = try self.formatTimestamp(@intCast(timestamp)),
            .bids = bids.toOwnedSlice(),
            .asks = asks.toOwnedSlice(),
            .nonce = null,
        };
    }

    pub fn fetchOHLCV(self: *Upbit, symbol: []const u8, timeframe: []const u8, since: ?i64, limit: ?u32) ![]OHLCV {
        _ = self;
        _ = symbol;
        _ = timeframe;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }
    
    pub fn fetchTrades(self: *Upbit, symbol: []const u8, since: ?i64, limit: ?u32) ![]models.Trade {
        const limit_param = if (limit) |l| std.fmt.allocPrint(self.allocator, "&count={d}", .{l}) else "";
        defer if (limit_param.len > 0) self.allocator.free(limit_param);
        
        const url = try std.fmt.allocPrint(self.allocator, "https://api.upbit.com/v1/trades/ticks?market={s}{s}", .{ symbol, limit_param });
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
            const timestamp = trade_data.object.get("timestamp").?.number.asInt();
            const price = trade_data.object.get("trade_price").?.number.asFloat();
            const volume = trade_data.object.get("trade_volume").?.number.asFloat();
            const side = trade_data.object.get("ask_bid").?.string;
            
            try trades.append(models.Trade{
                .id = try std.fmt.allocPrint(self.allocator, "{d}", .{timestamp}),
                .timestamp = @intCast(timestamp),
                .datetime = try self.formatTimestamp(@intCast(timestamp)),
                .symbol = try self.allocator.dupe(u8, symbol),
                .type = models.TradeType.spot,
                .side = if (std.mem.eql(u8, side, "BID")) "buy" else "sell",
                .price = price,
                .amount = volume,
                .cost = price * volume,
                .info = trade_data,
            });
        }
        
        return trades.toOwnedSlice();
    }
    
    // Private endpoints (require authentication)
    pub fn fetchBalance(self: *Upbit) ![]models.Balance {
        const url = "https://api.upbit.com/v1/accounts";
        
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
            const balance = balance_data.object.get("balance").?.number.asFloat();
            const locked = balance_data.object.get("locked").?.number.asFloat();
            
            if (balance > 0 or locked > 0) {
                try balances.append(models.Balance{
                    .currency = try self.allocator.dupe(u8, currency.string),
                    .free = balance,
                    .used = locked,
                    .total = balance + locked,
                });
            }
        }
        
        return balances.toOwnedSlice();
        }

        // Order management methods
        pub fn createOrder(
        self: *Upbit,
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
            "market={s}&side={s}&volume={d}&ord_type={s}",
            .{ market.id, side_str, amount, type_str }));

        if (price) |p| {
            try body.appendSlice(try std.fmt.allocPrint(self.allocator, "&price={d}", .{p}));
        }

        const url = "https://api.upbit.com/v1/orders";

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

        const uuid = parsed.object.get("uuid").?.string orelse return error.NetworkError;

        return Order{
            .id = try self.allocator.dupe(u8, uuid),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = try self.allocator.dupe(u8, type_str),
            .side = try self.allocator.dupe(u8, side_str),
            .price = price,
            .amount = amount,
            .status = try self.allocator.dupe(u8, "open"),
            .timestamp = std.time.milliTimestamp(),
            .info = parsed,
        };
        }

        pub fn cancelOrder(self: *Upbit, order_id: []const u8, symbol: []const u8) !Order {
        if (self.base.auth_config.apiKey == null or self.base.auth_config.apiSecret == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator, "https://api.upbit.com/v1/order?uuid={s}", .{ order_id });
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

        const uuid = parsed.object.get("uuid").?.string orelse return error.NetworkError;
        const state = parsed.object.get("state").?.string orelse return error.NetworkError;

        return Order{
            .id = try self.allocator.dupe(u8, uuid),
            .symbol = try self.allocator.dupe(u8, symbol),
            .status = try self.allocator.dupe(u8, state),
            .timestamp = std.time.milliTimestamp(),
            .info = parsed,
        };
        }

        pub fn fetchOrder(self: *Upbit, order_id: []const u8, symbol: []const u8) !Order {
        if (self.base.auth_config.apiKey == null or self.base.auth_config.apiSecret == null) {
            return error.AuthenticationRequired;
        }

        const url = try std.fmt.allocPrint(self.allocator, "https://api.upbit.com/v1/order?uuid={s}", .{ order_id });
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

        const uuid = parsed.object.get("uuid").?.string orelse return error.NetworkError;
        const state = parsed.object.get("state").?.string orelse return error.NetworkError;
        const ord_type = parsed.object.get("ord_type").?.string orelse return error.NetworkError;
        const side = parsed.object.get("side").?.string orelse return error.NetworkError;
        const price = parsed.object.get("price").?.number.asFloat();
        const volume = parsed.object.get("volume").?.number.asFloat();

        return Order{
            .id = try self.allocator.dupe(u8, uuid),
            .symbol = try self.allocator.dupe(u8, symbol),
            .type = try self.allocator.dupe(u8, ord_type),
            .side = try self.allocator.dupe(u8, side),
            .price = price,
            .amount = volume,
            .status = try self.allocator.dupe(u8, state),
            .timestamp = std.time.milliTimestamp(),
            .info = parsed,
        };
        }

        pub fn fetchOpenOrders(self: *Upbit, symbol: ?[]const u8) ![]Order {
        if (self.base.auth_config.apiKey == null or self.base.auth_config.apiSecret == null) {
            return error.AuthenticationRequired;
        }

        var url = "https://api.upbit.com/v1/orders";
        if (symbol) |s| {
            const market = self.base.findMarket(s) orelse return error.SymbolNotFound;
            url = try std.fmt.allocPrint(self.allocator, "https://api.upbit.com/v1/orders?market={s}", .{ market.id });
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
            const uuid = order_data.object.get("uuid").?.string orelse continue;
            const market = order_data.object.get("market").?.string orelse continue;
            const state = order_data.object.get("state").?.string orelse continue;
            const ord_type = order_data.object.get("ord_type").?.string orelse continue;
            const side = order_data.object.get("side").?.string orelse continue;
            const price = order_data.object.get("price").?.number.asFloat();
            const volume = order_data.object.get("volume").?.number.asFloat();

            try orders.append(Order{
                .id = try self.allocator.dupe(u8, uuid),
                .symbol = try self.allocator.dupe(u8, market),
                .type = try self.allocator.dupe(u8, ord_type),
                .side = try self.allocator.dupe(u8, side),
                .price = price,
                .amount = volume,
                .status = try self.allocator.dupe(u8, state),
                .timestamp = std.time.milliTimestamp(),
                .info = order_data,
            });
        }

        return orders.toOwnedSlice();
        }

        pub fn fetchClosedOrders(self: *Upbit, symbol: ?[]const u8, since: ?i64, limit: ?u32) ![]Order {
        if (self.base.auth_config.apiKey == null or self.base.auth_config.apiSecret == null) {
            return error.AuthenticationRequired;
        }

        var query = std.ArrayList(u8).init(self.allocator);
        defer query.deinit();

        if (symbol) |s| {
            const market = self.base.findMarket(s) orelse return error.SymbolNotFound;
            try query.appendSlice(try std.fmt.allocPrint(self.allocator, "market={s}", .{ market.id }));
        }

        if (since) |s| {
            if (query.len > 0) try query.append('&');
            try query.appendSlice(try std.fmt.allocPrint(self.allocator, "state=cancel,done&from={d}", .{ s }));
        }

        if (limit) |l| {
            if (query.len > 0) try query.append('&');
            try query.appendSlice(try std.fmt.allocPrint(self.allocator, "limit={d}", .{ l }));
        }

        var url = "https://api.upbit.com/v1/orders";
        if (query.len > 0) {
            url = try std.fmt.allocPrint(self.allocator, "https://api.upbit.com/v1/orders?{s}", .{ query.items });
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
            const uuid = order_data.object.get("uuid").?.string orelse continue;
            const market = order_data.object.get("market").?.string orelse continue;
            const state = order_data.object.get("state").?.string orelse continue;
            const ord_type = order_data.object.get("ord_type").?.string orelse continue;
            const side = order_data.object.get("side").?.string orelse continue;
            const price = order_data.object.get("price").?.number.asFloat();
            const volume = order_data.object.get("volume").?.number.asFloat();

            try orders.append(Order{
                .id = try self.allocator.dupe(u8, uuid),
                .symbol = try self.allocator.dupe(u8, market),
                .type = try self.allocator.dupe(u8, ord_type),
                .side = try self.allocator.dupe(u8, side),
                .price = price,
                .amount = volume,
                .status = try self.allocator.dupe(u8, state),
                .timestamp = std.time.milliTimestamp(),
                .info = order_data,
            });
        }

        return orders.toOwnedSlice();
        }

        // Authentication (Upbit uses JWT token)
        fn authenticate(self: *Upbit, headers: *std.StringHashMap([]const u8)) !void {
        const access_key = self.base.auth_config.apiKey orelse return error.AuthenticationRequired;
        const secret_key = self.base.auth_config.apiSecret orelse return error.AuthenticationRequired;
        
        const timestamp = std.time.milliTimestamp();
        const query_hash = crypto.sha256(""); // Empty body
        const message = try std.fmt.allocPrint(self.allocator, "{d}", .{timestamp});
        defer self.allocator.free(message);
        
        const signature = crypto.hmacSha256(secret_key, message);
        
        try headers.put(try self.allocator.dupe(u8, "Authorization"), try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{signature}));
        try headers.put(try self.allocator.dupe(u8, "Accept"), try self.allocator.dupe(u8, "application/json"));
    }
    
    // Helper functions
    fn formatTimestamp(self: *Upbit, timestamp: i64) ![]const u8 {
        const dt = std.time.epoch.Milliseconds{ .milliseconds = @as(u64, @intCast(timestamp)) };
        const time = dt.toTime();
        
        return std.fmt.allocPrint(self.allocator, "{d}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
            time.year, time.month, time.day, time.hour, time.minute, time.second
        });
    }
};

// Import required modules
const models = @Import("../models/types.zig");
const error = @Import("../base/errors.zig");