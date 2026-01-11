const std = @import("std");
const base = @import("../base/exchange.zig");
const json = @import("../utils/json.zig");
const auth = @import("../base/auth.zig");
const precision = @import("../utils/precision.zig");
const crypto = @import("../utils/crypto.zig");

// Mercado Bitcoin Exchange Implementation
// Mercado Bitcoin is a major Brazilian cryptocurrency exchange
// Documentation: https://www.mercadobitcoin.com.br/api-doc/

pub const MercadoBitcoin = struct {
    allocator: std.mem.Allocator,
    base: base.Exchange,
    
    pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*MercadoBitcoin {
        const mb = try allocator.create(MercadoBitcoin);
        mb.allocator = allocator;
        
        mb.base = try base.Exchange.init(allocator, auth_config);
        try mb.base.configure(.{
            .name = "mercado",
            .display_name = "Mercado Bitcoin",
            .api_urls = .{
                .rest = "https://www.mercadobitcoin.com.br/api",
                .ws = null, // No WebSocket support
            },
            .precision_mode = precision.PrecisionMode.decimal_places,
            .supports_spot = true,
            .supports_margin = false,
            .supports_futures = false,
        });
        
        return mb;
    }
    
    pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*MercadoBitcoin {
        const mb = try allocator.create(MercadoBitcoin);
        mb.allocator = allocator;
        
        mb.base = try base.Exchange.init(allocator, auth_config);
        try mb.base.configure(.{
            .name = "mercado",
            .display_name = "Mercado Bitcoin Testnet",
            .api_urls = .{
                .rest = "https://sandbox.mercadobitcoin.com.br/api",
                .ws = null,
            },
            .precision_mode = precision.PrecisionMode.decimal_places,
            .supports_spot = true,
            .supports_margin = false,
            .supports_futures = false,
        });
        
        return mb;
    }
    
    pub fn deinit(self: *MercadoBitcoin) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }
    
    pub fn fetchMarkets(self: *MercadoBitcoin) ![]models.Market {
        const url = "https://www.mercadobitcoin.com.br/api/v4/trading-pairs/";
        
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
        
        for (parsed.array.items) |pair_data| {
            const trading_pair = pair_data.object.get("trading_pair") orelse continue;
            const base_currency = pair_data.object.get("base_currency") orelse continue;
            const quote_currency = pair_data.object.get("quote_currency") orelse continue;
            const base_precision = pair_data.object.get("base_precision") orelse continue;
            const quote_precision = pair_data.object.get("quote_precision") orelse continue;
            
            // Split trading pair like "BTCBRL" into "BTC/BRL"
            const base_symbol = std.mem.split(u8, trading_pair.string, quote_currency.string).first() orelse continue;
            
            var market = models.Market{
                .id = try self.allocator.dupe(u8, trading_pair.string),
                .symbol = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base_symbol, quote_currency.string }),
                .base = try self.allocator.dupe(u8, base_symbol),
                .quote = try self.allocator.dupe(u8, quote_currency.string),
                .active = true,
                .spot = true,
                .margin = false,
                .future = false,
                .limits = .{
                    .amount = .{
                        .min = pair_data.object.get("min_amount").?.number.asFloat(),
                        .max = null,
                    },
                    .price = .{
                        .min = pair_data.object.get("min_value").?.number.asFloat(),
                        .max = null,
                    },
                    .cost = .{
                        .min = null,
                        .max = null,
                    },
                },
                .precision = .{
                    .amount = base_precision.number.asInt(),
                    .price = quote_precision.number.asInt(),
                },
                .info = parsed,
            };
            
            try markets.append(market);
        }
        
        return markets.toOwnedSlice();
    }
    
    pub fn fetchTicker(self: *MercadoBitcoin, symbol: []const u8) !models.Ticker {
        const parts = std.mem.split(u8, symbol, "/");
        const base_currency = parts.first() orelse return error.NetworkError;
        const quote_currency = parts.rest() orelse return error.NetworkError;
        const trading_pair = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ base_currency, quote_currency });
        defer self.allocator.free(trading_pair);
        
        const url = try std.fmt.allocPrint(self.allocator, "https://www.mercadobitcoin.com.br/api/v4/{s}/ticker/", .{trading_pair});
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
        
        const high = parsed.object.get("high").?.number.asFloat();
        const low = parsed.object.get("low").?.number.asFloat();
        const bid = parsed.object.get("bid").?.number.asFloat();
        const ask = parsed.object.get("ask").?.number.asFloat();
        const last = parsed.object.get("last").?.number.asFloat();
        const volume = parsed.object.get("volume").?.number.asFloat();
        
        return models.Ticker{
            .symbol = try self.allocator.dupe(u8, symbol),
            .timestamp = std.time.milliTimestamp(),
            .high = high,
            .low = low,
            .bid = bid,
            .ask = ask,
            .last = last,
            .baseVolume = volume,
            .quoteVolume = null,
            .percentage = null,
            .info = parsed,
        };
    }
    
    pub fn fetchOrderBook(self: *MercadoBitcoin, symbol: []const u8, limit: ?usize) !models.OrderBook {
        const parts = std.mem.split(u8, symbol, "/");
        const base_currency = parts.first() orelse return error.NetworkError;
        const quote_currency = parts.rest() orelse return error.NetworkError;
        const trading_pair = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ base_currency, quote_currency });
        defer self.allocator.free(trading_pair);
        
        const limit_param = if (limit) |l| std.fmt.allocPrint(self.allocator, "?depth={d}", .{l}) else "";
        defer if (limit_param.len > 0) self.allocator.free(limit_param);
        
        const url = try std.fmt.allocPrint(self.allocator, "https://www.mercadobitcoin.com.br/api/v4/{s}/orderbook{s}", .{ trading_pair, limit_param });
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
    
    pub fn fetchTrades(self: *MercadoBitcoin, symbol: []const u8, since: ?i64, limit: ?usize) ![]models.Trade {
        const parts = std.mem.split(u8, symbol, "/");
        const base_currency = parts.first() orelse return error.NetworkError;
        const quote_currency = parts.rest() orelse return error.NetworkError;
        const trading_pair = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ base_currency, quote_currency });
        defer self.allocator.free(trading_pair);
        
        const limit_param = if (limit) |l| std.fmt.allocPrint(self.allocator, "?limit={d}", .{l}) else "";
        defer if (limit_param.len > 0) self.allocator.free(limit_param);
        
        const url = try std.fmt.allocPrint(self.allocator, "https://www.mercadobitcoin.com.br/api/v4/{s}/trades{s}", .{ trading_pair, limit_param });
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
            const date = trade_data.object.get("date").?.number.asInt();
            const price = trade_data.object.get("price").?.number.asFloat();
            const amount = trade_data.object.get("amount").?.number.asFloat();
            const tid = trade_data.object.get("tid").?.number.asInt();
            const side = trade_data.object.get("side").?.string;
            
            try trades.append(models.Trade{
                .id = try std.fmt.allocPrint(self.allocator, "{d}", .{tid}),
                .timestamp = @intCast(date * 1000), // Convert to milliseconds
                .datetime = try self.formatTimestamp(@intCast(date * 1000)),
                .symbol = try self.allocator.dupe(u8, symbol),
                .type = models.TradeType.spot,
                .side = try self.allocator.dupe(u8, side orelse "buy"),
                .price = price,
                .amount = amount,
                .cost = price * amount,
                .info = trade_data,
            });
        }
        
        return trades.toOwnedSlice();
    }
    
    // Private endpoints (require authentication)
    pub fn fetchBalance(self: *MercadoBitcoin) ![]models.Balance {
        const url = "https://www.mercadobitcoin.com.br/api/v4/balance/";
        
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
        
        var iterator = parsed.object.iterator();
        while (iterator.next()) |entry| {
            const currency = entry.key_ptr.*;
            const balance_data = entry.value_ptr.*;
            
            const total = balance_data.object.get("total") orelse continue;
            const available = balance_data.object.get("available") orelse continue;
            const locked = balance_data.object.get("locked") orelse continue;
            
            if (total.number.asFloat() > 0) {
                try balances.append(models.Balance{
                    .currency = try self.allocator.dupe(u8, currency),
                    .free = available.number.asFloat(),
                    .used = locked.number.asFloat(),
                    .total = total.number.asFloat(),
                });
            }
        }
        
        return balances.toOwnedSlice();
    }
    
    // Authentication
    fn authenticate(self: *MercadoBitcoin, headers: *std.StringHashMap([]const u8)) !void {
        const api_key = self.base.auth_config.apiKey orelse return error.AuthenticationRequired;
        const api_secret = self.base.auth_config.apiSecret orelse return error.AuthenticationRequired;
        
        const timestamp = std.time.milliTimestamp();
        const nonce = try std.fmt.allocPrint(self.allocator, "{}", .{timestamp});
        defer self.allocator.free(nonce);
        
        const message = try std.fmt.allocPrint(self.allocator, "{}", .{timestamp});
        defer self.allocator.free(message);
        
        const signature = crypto.hmacSha256(api_secret, message);
        
        const auth_header = try std.fmt.allocPrint(self.allocator, "Basic {s}:{s}", .{ api_key, signature });
        defer self.allocator.free(auth_header);
        
        try headers.put(try self.allocator.dupe(u8, "Authorization"), auth_header);
    }
    
    // Helper functions
    fn formatTimestamp(self: *MercadoBitcoin, timestamp: i64) ![]const u8 {
        const dt = std.time.epoch.Milliseconds{ .milliseconds = @as(u64, @intCast(timestamp)) };
        const time = dt.toTime();
        
        return std.fmt.allocPrint(self.allocator, "{d}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
            time.year, time.month, time.day, time.hour, time.minute, time.second
        });
    }
};

// Import required modules
const models = @import("../models/types.zig");
const error = @import("../base/errors.zig");