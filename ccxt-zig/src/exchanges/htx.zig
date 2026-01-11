const std = @import("std");
const exchange = @import("../base/exchange.zig");
const auth = @import("../base/auth.zig");
const errors = @import("../base/errors.zig");
const http = @import("../base/http.zig");
const json = @import("../utils/json.zig");
const time = @import("../utils/time.zig");
const crypto = @import("../utils/crypto.zig");
const precision_utils = @import("../utils/precision.zig");

// Import models
const Market = @import("../models/market.zig").Market;
const MarketPrecision = @import("../models/market.zig").MarketPrecision;
const Ticker = @import("../models/ticker.zig").Ticker;
const OrderBook = @import("../models/orderbook.zig").OrderBook;
const OrderBookEntry = @import("../models/orderbook.zig").OrderBookEntry;
const Order = @import("../models/order.zig").Order;
const OrderType = @import("../models/order.zig").OrderType;
const OrderSide = @import("../models/order.zig").OrderSide;
const Balance = @import("../models/balance.zig").Balance;
const Trade = @import("../models/trade.zig").Trade;
const TradeType = @import("../models/trade.zig").TradeType;
const OHLCV = @import("../models/ohlcv.zig").OHLCV;

// HTX Exchange - Huobi rebrand
// HTX (formerly Huobi) is a major global cryptocurrency exchange
// Documentation: https://huobiapi.github.io/docs/spot/v1/en/

pub const HTX = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    api_key: ?[]const u8,
    secret_key: ?[]const u8,
    testnet: bool,
    
    pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*HTX {
        const self = try allocator.create(HTX);
        self.allocator = allocator;
        self.api_key = auth_config.apiKey;
        self.secret_key = auth_config.apiSecret;
        self.testnet = false;
        
        var http_client = try http.HttpClient.init(allocator);
        const base_name = try allocator.dupe(u8, "htx");
        const base_url = try allocator.dupe(u8, "https://api.huobi.pro");
        const ws_url = try allocator.dupe(u8, "wss://api.huobi.pro/ws");

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
    
    pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*HTX {
        const self = try allocator.create(HTX);
        self.allocator = allocator;
        self.api_key = auth_config.apiKey;
        self.secret_key = auth_config.apiSecret;
        self.testnet = true;
        
        var http_client = try http.HttpClient.init(allocator);
        const base_name = try allocator.dupe(u8, "htx");
        const base_url = try allocator.dupe(u8, "https://api.huobi.pro"); // HTX doesn't have separate testnet
        const ws_url = try allocator.dupe(u8, "wss://api.huobi.pro/ws");

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
    
    pub fn deinit(self: *HTX) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }
    
    // HTX uses HMAC-SHA256 authentication similar to Huobi
    pub fn sign(self: *HTX, endpoint: []const u8, body: []const u8) !void {
        const timestamp = try std.fmt.allocPrint(self.allocator, "{d}", .{std.time.milliTimestamp()});
        defer self.allocator.free(timestamp);
        
        const method = "POST";
        const host = "api.huobi.pro";
        const uri = endpoint;
        
        var presigned = std.ArrayList(u8).init(self.allocator);
        defer presigned.deinit();
        
        try presigned.appendSlice(method);
        try presigned.append('\n');
        try presigned.appendSlice(host);
        try presigned.append('\n');
        try presigned.appendSlice(uri);
        try presigned.append('\n');
        
        // Add query string if present
        if (body.len > 0) {
            try presigned.appendSlice(body);
        }
        
        try presigned.append('\n');
        try presigned.appendSlice(timestamp);
        
        const signing_key = self.base.auth_config.apiSecret orelse return error.AuthenticationRequired;
        const signature = crypto.hmacSha256(signing_key, presigned.items);
        
        const signature_header = try std.fmt.allocPrint(self.allocator, "HmacSHA256:{s}", .{signature});
        defer self.allocator.free(signature_header);
        
        try self.base.http_client.addHeader("Authorization", signature_header);
        try self.base.http_client.addHeader("Content-Type", "application/json");
        try self.base.http_client.addHeader("Accept", "application/json");
        try self.base.http_client.addHeader("Accept-Charset", "UTF-8");
        try self.base.http_client.addHeader("X-TS-API", timestamp);
    }
    
    pub fn fetchMarkets(self: *HTX) ![]models.Market {
        const url = "https://api.huobi.pro/v1/common/symbols";
        
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
        
        const data = parsed.object.get("data") orelse return error.NetworkError;
        const symbols = data.array.items;
        
        for (symbols) |symbol_json| {
            const symbol_data = symbol_json.object;
            
            const base_currency = symbol_data.get("base-currency") orelse continue;
            const quote_currency = symbol_data.get("quote-currency") orelse continue;
            const symbol = symbol_data.get("symbol") orelse continue;
            const state = symbol_data.get("state") orelse continue;
            
            if (!std.mem.eql(u8, state.string, "online")) continue;
            
            const price_precision = symbol_data.get("price-precision") orelse continue;
            const amount_precision = symbol_data.get("amount-precision") orelse continue;
            
            var market = models.Market{
                .id = try self.allocator.dupe(u8, symbol.string),
                .symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base_currency.string, quote_currency.string }),
                .base = try self.allocator.dupe(u8, base_currency.string),
                .quote = try self.allocator.dupe(u8, quote_currency.string),
                .active = std.mem.eql(u8, state.string, "online"),
                .spot = true,
                .margin = false,
                .future = false,
                .limits = .{
                    .amount = .{
                        .min = null,
                        .max = null,
                    },
                    .price = .{
                        .min = null,
                        .max = null,
                    },
                    .cost = .{
                        .min = null,
                        .max = null,
                    },
                },
                .precision = .{
                    .amount = amount_precision.number.asInt(),
                    .price = price_precision.number.asInt(),
                },
                .info = parsed,
            };
            
            try markets.append(market);
        }
        
        return markets.toOwnedSlice();
    }
    
    pub fn fetchTicker(self: *HTX, symbol: []const u8) !models.Ticker {
        const url = try std.fmt.allocPrint(self.allocator, "https://api.huobi.pro/market/detail/merged?symbol={s}", .{symbol});
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
        
        const tick = parsed.object.get("tick") orelse return error.NetworkError;
        const bid = tick.object.get("bid") orelse return error.NetworkError;
        const ask = tick.object.get("ask") orelse return error.NetworkError;
        const open = tick.object.get("open") orelse return error.NetworkError;
        const close = tick.object.get("close") orelse return error.NetworkError;
        const high = tick.object.get("high") orelse return error.NetworkError;
        const low = tick.object.get("low") orelse return error.NetworkError;
        const vol = tick.object.get("vol") orelse return error.NetworkError;
        
        return models.Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = std.time.milliTimestamp(),
            .high = high.number.asFloat(),
            .low = low.number.asFloat(),
            .bid = bid.object.get("price").?.number.asFloat(),
            .ask = ask.object.get("price").?.number.asFloat(),
            .last = close.number.asFloat(),
            .baseVolume = vol.number.asFloat(),
            .quoteVolume = null,
            .percentage = null,
            .info = parsed,
        };
    }
    
    pub fn fetchOrderBook(self: *HTX, symbol: []const u8, limit: ?usize) !models.OrderBook {
        const limit_param = if (limit) |l| std.fmt.allocPrint(self.allocator, "&type=step1&depth={d}", .{l}) else "";
        defer if (limit_param.len > 0) self.allocator.free(limit_param);
        
        const url = try std.fmt.allocPrint(self.allocator, "https://api.huobi.pro/market/depth?symbol={s}{s}", .{ symbol, limit_param });
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
        
        const tick = parsed.object.get("tick") orelse return error.NetworkError;
        const bids_data = tick.object.get("bids") orelse return error.NetworkError;
        const asks_data = tick.object.get("asks") orelse return error.NetworkError;
        
        var bids = std.ArrayList(models.OrderBookEntry).init(self.allocator);
        var asks = std.ArrayList(models.OrderBookEntry).init(self.allocator);
        
        for (bids_data.array.items) |bid_data| {
            const price = bid_data.array.items[0].number.asFloat();
            const amount = bid_data.array.items[1].number.asFloat();
            
            try bids.append(models.OrderBookEntry{
                .price = price,
                .amount = amount,
                .timestamp = std.time.milliTimestamp(),
            });
        }
        
        for (asks_data.array.items) |ask_data| {
            const price = ask_data.array.items[0].number.asFloat();
            const amount = ask_data.array.items[1].number.asFloat();
            
            try asks.append(models.OrderBookEntry{
                .price = price,
                .amount = amount,
                .timestamp = std.time.milliTimestamp(),
            });
        }
        
        return models.OrderBook{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = std.time.milliTimestamp(),
            .datetime = try self.formatTimestamp(std.time.milliTimestamp()),
            .bids = bids.toOwnedSlice(),
            .asks = asks.toOwnedSlice(),
            .nonce = null,
        };
    }
    
    pub fn fetchTrades(self: *HTX, symbol: []const u8, since: ?i64, limit: ?usize) ![]models.Trade {
        const limit_param = if (limit) |l| std.fmt.allocPrint(self.allocator, "&size={d}", .{l}) else "";
        defer if (limit_param.len > 0) self.allocator.free(limit_param);
        
        const url = try std.fmt.allocPrint(self.allocator, "https://api.huobi.pro/market/history/trade?symbol={s}{s}", .{ symbol, limit_param });
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
        
        const data = parsed.object.get("data") orelse return error.NetworkError;
        var trades = std.ArrayList(models.Trade).init(self.allocator);
        
        for (data.array.items) |trade_data| {
            const ts = trade_data.object.get("ts").?.number.asInt();
            const price = trade_data.object.get("price").?.number.asFloat();
            const amount = trade_data.object.get("amount").?.number.asFloat();
            const direction = trade_data.object.get("direction").?.string;
            
            try trades.append(models.Trade{
                .id = try std.fmt.allocPrint(self.allocator, "{d}", .{ts}),
                .timestamp = ts,
                .datetime = try self.formatTimestamp(ts),
                .symbol = try self.allocator.dupe(u8, symbol),
                .type = models.TradeType.spot,
                .side = try self.allocator.dupe(u8, direction),
                .price = price,
                .amount = amount,
                .cost = price * amount,
                .info = trade_data,
            });
        }
        
        return trades.toOwnedSlice();
    }
    
    // Private endpoints (require authentication)
    pub fn fetchBalance(self: *HTX) ![]models.Balance {
        try self.sign("/v1/account/accounts/{self.base.account_id}/balance/balance", "");
        
        const url = "https://api.huobi.pro/v1/account/accounts/{self.base.account_id}/balance/balance";
        
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        
        const response = try self.base.http_client.get(url, &headers);
        defer response.deinit(self.allocator);
        
        if (response.status != 200) {
            return error.AuthenticationRequired;
        }
        
        var parser = json.JsonParser.init(self.allocator);
        defer parser.deinit();
        
        const parsed = try parser.parse(response.body);
        defer parsed.deinit();
        
        const data = parsed.object.get("data") orelse return error.AuthenticationRequired;
        var balances = std.ArrayList(models.Balance).init(self.allocator);
        
        for (data.array.items) |balance_data| {
            const currency = balance_data.object.get("currency").?.string;
            const balance_type = balance_data.object.get("balance-type").?.string;
            
            if (std.mem.eql(u8, balance_type, "trade")) {
                const available = balance_data.object.get("available").?.number.asFloat();
                const frozen = balance_data.object.get("balance").?.number.asFloat() - available;
                
                try balances.append(models.Balance{
                    .currency = try self.allocator.dupe(u8, currency),
                    .free = available,
                    .used = frozen,
                    .total = available + frozen,
                });
            }
        }
        
        return balances.toOwnedSlice();
    }
    
    // Exchange-specific helpers
    fn formatTimestamp(self: *HTX, timestamp: i64) ![]const u8 {
        const dt = std.time.epoch.Milliseconds{ .milliseconds = @as(u64, @intCast(timestamp)) };
        const time = dt.toTime();
        
        return std.fmt.allocPrint(self.allocator, "{d}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
            time.year, time.month, time.day, time.hour, time.minute, time.second
        });
    }
};

// Import required modules
const json = @import("../utils/json.zig");
const crypto = @import("../utils/crypto.zig");