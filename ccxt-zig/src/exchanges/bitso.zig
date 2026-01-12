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

// BitSO Exchange Implementation
// BitSO is the leading Latin American cryptocurrency exchange
// Documentation: https://bitso.com/

pub const BitSO = struct {
    allocator: std.mem.Allocator,
    base: base.Exchange,
    
    pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*BitSO {
        const bitso = try allocator.create(BitSO);
        bitso.allocator = allocator;
        
        bitso.base = try base.Exchange.init(allocator, auth_config);
        try bitso.base.configure(.{
            .name = "bitso",
            .display_name = "BitSO",
            .api_urls = .{
                .rest = "https://api.bitso.com/v3",
                .ws = "wss://ws.bitso.com",
            },
            .precision_mode = precision.PrecisionMode.decimal_places,
            .supports_spot = true,
            .supports_margin = true,
            .supports_futures = false,
        });
        
        return bitso;
    }
    
    pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*BitSO {
        const bitso = try allocator.create(BitSO);
        bitso.allocator = allocator;
        
        bitso.base = try base.Exchange.init(allocator, auth_config);
        try bitso.base.configure(.{
            .name = "bitso",
            .display_name = "BitSO Sandbox",
            .api_urls = .{
                .rest = "https://api-staging.bitso.com/v3",
                .ws = "wss://ws-staging.bitso.com",
            },
            .precision_mode = precision.PrecisionMode.decimal_places,
            .supports_spot = true,
            .supports_margin = true,
            .supports_futures = false,
        });
        
        return bitso;
    }
    
    pub fn deinit(self: *BitSO) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }
    
    // Template exchange - methods return error.NotImplemented
    // Full API implementation pending future development
    pub fn fetchMarkets(self: *BitSO) ![]models.Market {
        const url = "https://api.bitso.com/v3/available_books/";
        
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
        
        const success = parsed.object.get("success") orelse return error.NetworkError;
        if (!success.boolean) {
            return error.NetworkError;
        }
        
        var markets = std.ArrayList(models.Market).init(self.allocator);
        const books = parsed.object.get("payload") orelse return error.NetworkError;
        
        for (books.array.items) |book_json| {
            const book_data = book_json.object;
            
            const book = book_data.get("book") orelse continue;
            const base_currency = book_data.get("base_currency") orelse continue;
            const quote_currency = book_data.get("quote_currency") orelse continue;
            const minimum_value = book_data.get("minimum_value") orelse continue;
            const minimum_amount = book_data.get("minimum_amount") orelse continue;
            
            var market = models.Market{
                .id = try self.allocator.dupe(u8, book.string),
                .symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base_currency.string, quote_currency.string }),
                .base = try self.allocator.dupe(u8, base_currency.string),
                .quote = try self.allocator.dupe(u8, quote_currency.string),
                .active = true,
                .spot = true,
                .margin = false,
                .future = false,
                .limits = .{
                    .amount = .{
                        .min = minimum_amount.number.asFloat(),
                        .max = null,
                    },
                    .price = .{
                        .min = minimum_value.number.asFloat(),
                        .max = null,
                    },
                    .cost = .{
                        .min = null,
                        .max = null,
                    },
                },
                .precision = .{
                    .amount = 8, // Default for BitSO
                    .price = 8,  // Default for BitSO
                },
                .info = parsed,
            };
            
            try markets.append(market);
        }
        
        return markets.toOwnedSlice();
    }
    
    pub fn fetchTicker(self: *BitSO, symbol: []const u8) !models.Ticker {
        const url = try std.fmt.allocPrint(self.allocator, "https://api.bitso.com/v3/ticker/?book={s}", .{symbol});
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
        
        const success = parsed.object.get("success") orelse return error.NetworkError;
        if (!success.boolean) {
            return error.NetworkError;
        }
        
        const data = parsed.object.get("payload") orelse return error.NetworkError;
        const high = data.object.get("high") orelse return error.NetworkError;
        const low = data.object.get("low") orelse return error.NetworkError;
        const bid = data.object.get("bid") orelse return error.NetworkError;
        const ask = data.object.get("ask") orelse return error.NetworkError;
        const last = data.object.get("last") orelse return error.NetworkError;
        const volume = data.object.get("volume") orelse return error.NetworkError;
        
        return models.Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = std.time.milliTimestamp(),
            .high = high.number.asFloat(),
            .low = low.number.asFloat(),
            .bid = bid.number.asFloat(),
            .ask = ask.number.asFloat(),
            .last = last.number.asFloat(),
            .baseVolume = volume.number.asFloat(),
            .quoteVolume = null,
            .percentage = null,
            .info = parsed,
        };
    }
    
    pub fn fetchOrderBook(self: *BitSO, symbol: []const u8, limit: ?u32) !models.OrderBook {
        const limit_param = if (limit) |l| std.fmt.allocPrint(self.allocator, "&aggregate={d}", .{l}) else "";
        defer if (limit_param.len > 0) self.allocator.free(limit_param);
        
        const url = try std.fmt.allocPrint(self.allocator, "https://api.bitso.com/v3/order_book/{s}{s}", .{ symbol, limit_param });
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
        
        const success = parsed.object.get("success") orelse return error.NetworkError;
        if (!success.boolean) {
            return error.NetworkError;
        }
        
        const data = parsed.object.get("payload") orelse return error.NetworkError;
        const bids_data = data.object.get("bids") orelse return error.NetworkError;
        const asks_data = data.object.get("asks") orelse return error.NetworkError;
        
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

    pub fn fetchOHLCV(self: *BitSO, symbol: []const u8, timeframe: []const u8, since: ?i64, limit: ?u32) ![]OHLCV {
        _ = self;
        _ = symbol;
        _ = timeframe;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }
    
    pub fn fetchTrades(self: *BitSO, symbol: []const u8, since: ?i64, limit: ?u32) ![]models.Trade {
        const limit_param = if (limit) |l| std.fmt.allocPrint(self.allocator, "?book={s}&limit={d}", .{ symbol, l }) else std.fmt.allocPrint(self.allocator, "?book={s}", .{symbol});
        defer self.allocator.free(limit_param);
        
        const url = try std.fmt.allocPrint(self.allocator, "https://api.bitso.com/v3/trades/{s}", .{limit_param});
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
        
        const success = parsed.object.get("success") orelse return error.NetworkError;
        if (!success.boolean) {
            return error.NetworkError;
        }
        
        var trades = std.ArrayList(models.Trade).init(self.allocator);
        const trades_data = parsed.object.get("payload") orelse return error.NetworkError;
        
        for (trades_data.array.items) |trade_data| {
            const book = trade_data.object.get("book") orelse continue;
            const created_at = trade_data.object.get("created_at") orelse continue;
            const amount = trade_data.object.get("amount") orelse continue;
            const book_value = trade_data.object.get("book_value") orelse continue;
            const side = trade_data.object.get("side") orelse continue;
            const price = trade_data.object.get("price") orelse continue;
            
            try trades.append(models.Trade{
                .id = try self.allocator.dupe(u8, created_at.string),
                .timestamp = try self.parseTimestamp(created_at.string),
                .datetime = created_at.string,
                .symbol = try self.allocator.dupe(u8, book.string),
                .type = models.TradeType.spot,
                .side = try self.allocator.dupe(u8, side.string),
                .price = price.number.asFloat(),
                .amount = amount.number.asFloat(),
                .cost = book_value.number.asFloat(),
                .info = trade_data,
            });
        }
        
        return trades.toOwnedSlice();
    }
    
    // Private endpoints (require authentication)
    pub fn fetchBalance(self: *BitSO) ![]models.Balance {
        const url = "https://api.bitso.com/v3/balance/";
        
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
        
        const success = parsed.object.get("success") orelse return error.AuthenticationRequired;
        if (!success.boolean) {
            return error.AuthenticationRequired;
        }
        
        var balances = std.ArrayList(models.Balance).init(self.allocator);
        const balances_data = parsed.object.get("payload") orelse return error.AuthenticationRequired;
        
        for (balances_data.array.items) |balance_data| {
            const currency = balance_data.object.get("currency") orelse continue;
            const available = balance_data.object.get("available") orelse continue;
            const locked = balance_data.object.get("locked") orelse continue;
            
            if (available.number.asFloat() > 0 or locked.number.asFloat() > 0) {
                try balances.append(models.Balance{
                    .currency = try self.allocator.dupe(u8, currency.string),
                    .free = available.number.asFloat(),
                    .used = locked.number.asFloat(),
                    .total = available.number.asFloat() + locked.number.asFloat(),
                });
            }
        }
        
        return balances.toOwnedSlice();
    }
    
    // Authentication
    fn authenticate(self: *BitSO, headers: *std.StringHashMap([]const u8)) !void {
        const api_key = self.base.auth_config.apiKey orelse return error.AuthenticationRequired;
        const api_secret = self.base.auth_config.apiSecret orelse return error.AuthenticationRequired;
        
        const timestamp = std.time.milliTimestamp();
        const nonce = try std.fmt.allocPrint(self.allocator, "{}", .{timestamp});
        defer self.allocator.free(nonce);
        
        const message = try std.fmt.allocPrint(self.allocator, "{}", .{timestamp});
        defer self.allocator.free(message);
        
        const signature = crypto.hmacSha256(api_secret, message);
        
        const auth_header = try std.fmt.allocPrint(self.allocator, "Bitso {s}:{s}", .{ api_key, signature });
        defer self.allocator.free(auth_header);
        
        try headers.put(try self.allocator.dupe(u8, "Authorization"), auth_header);
    }
    
    // Helper functions
    fn formatTimestamp(self: *BitSO, timestamp: i64) ![]const u8 {
        const dt = std.time.epoch.Milliseconds{ .milliseconds = @as(u64, @intCast(timestamp)) };
        const time = dt.toTime();
        
        return std.fmt.allocPrint(self.allocator, "{d}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
            time.year, time.month, time.day, time.hour, time.minute, time.second
        });
    }
    
    fn parseTimestamp(self: *BitSO, timestamp_str: []const u8) !i64 {
        // Parse ISO 8601 format: "2023-01-01T12:00:00.000Z"
        const parts = std.mem.split(u8, timestamp_str, "T");
        const date_part = parts.first() orelse return error.NetworkError;
        const time_part = parts.rest() orelse return error.NetworkError;
        
        // Simple implementation for demonstration
        // In production, use a proper ISO 8601 parser
        return std.time.milliTimestamp();
    }
};

// Import required modules
const models = @import("../models/types.zig");
const error = @import("../base/errors.zig");