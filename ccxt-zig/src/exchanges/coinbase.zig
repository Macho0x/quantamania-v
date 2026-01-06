const std = @import("std");
const BaseExchange = @import("../base/exchange.zig").BaseExchange;
const ExchangeConfig = @import("../base/exchange.zig").ExchangeConfig;
const OrderBook = @import("../base/exchange.zig").OrderBook;
const auth = @import("../base/auth.zig");
const types = @import("../base/types.zig");
const Market = @import("../models/market.zig").Market;
const Ticker = @import("../models/ticker.zig").Ticker;
const Order = @import("../models/order.zig").Order;
const Trade = @import("../models/trade.zig").Trade;
const OHLCV = @import("../models/ohlcv.zig").OHLCV;
const Balance = @import("../models/balance.zig").Balance;

pub const CoinbaseExchange = struct {
    base: BaseExchange,
    
    pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*CoinbaseExchange {
        const config = ExchangeConfig{
            .apiUrl = "https://api.exchange.coinbase.com",
            .wsUrl = "wss://ws-feed.exchange.coinbase.com",
            .rateLimit = 67, // 15 requests per second
            .enableRateLimit = true,
            .timeout = 30000,
            .verbose = false,
        };
        
        const exchange = try allocator.create(CoinbaseExchange);
        exchange.* = .{
            .base = try BaseExchange.init(allocator, "coinbase", "Coinbase", config, auth_config),
        };
        
        return exchange;
    }
    
    pub fn destroy(self: *CoinbaseExchange) void {
        self.base.deinit();
        self.base.allocator.destroy(self);
    }
    
    pub fn fetchMarkets(self: *CoinbaseExchange) ![]Market {
        self.base.throttle();
        
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/products",
            .{self.base.getApiUrl()},
        );
        defer self.base.allocator.free(url);
        
        const response = try self.base.http_client.get(url, null);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.ExchangeError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const products_array = parsed.value.array;
        var markets = std.ArrayList(Market).init(self.base.allocator);
        
        for (products_array.items) |product_obj| {
            const product = product_obj.object;
            
            const id_str = product.get("id").?.string;
            const base_currency = product.get("base_currency").?.string;
            const quote_currency = product.get("quote_currency").?.string;
            const status = product.get("status").?.string;
            
            const market = Market{
                .id = try self.base.allocator.dupe(u8, id_str),
                .symbol = try std.fmt.allocPrint(self.base.allocator, "{s}/{s}", .{ base_currency, quote_currency }),
                .base = try self.base.allocator.dupe(u8, base_currency),
                .quote = try self.base.allocator.dupe(u8, quote_currency),
                .baseId = try self.base.allocator.dupe(u8, base_currency),
                .quoteId = try self.base.allocator.dupe(u8, quote_currency),
                .active = std.mem.eql(u8, status, "online"),
                .spot = true,
                .margin = product.get("margin_enabled").?.bool,
                .future = false,
                .swap = false,
                .option = false,
                .contract = false,
            };
            
            try markets.append(market);
        }
        
        self.base.last_markets_fetch = std.time.milliTimestamp();
        return try markets.toOwnedSlice();
    }
    
    pub fn fetchTicker(self: *CoinbaseExchange, symbol: []const u8) !Ticker {
        self.base.throttle();
        
        const product_id = try self.symbolToCoinbase(symbol);
        defer self.base.allocator.free(product_id);
        
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/products/{s}/ticker",
            .{ self.base.getApiUrl(), product_id },
        );
        defer self.base.allocator.free(url);
        
        const response = try self.base.http_client.get(url, null);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.ExchangeError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const ticker_data = parsed.value.object;
        
        return Ticker{
            .symbol = try self.base.allocator.dupe(u8, symbol),
            .timestamp = std.time.milliTimestamp(),
            .bid = try std.fmt.parseFloat(f64, ticker_data.get("bid").?.string),
            .ask = try std.fmt.parseFloat(f64, ticker_data.get("ask").?.string),
            .last = try std.fmt.parseFloat(f64, ticker_data.get("price").?.string),
            .baseVolume = try std.fmt.parseFloat(f64, ticker_data.get("volume").?.string),
        };
    }
    
    pub fn fetchOrderBook(self: *CoinbaseExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        self.base.throttle();
        
        const product_id = try self.symbolToCoinbase(symbol);
        defer self.base.allocator.free(product_id);
        
        const level = if (limit) |l| if (l <= 50) 2 else 3 else 2;
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/products/{s}/book?level={d}",
            .{ self.base.getApiUrl(), product_id, level },
        );
        defer self.base.allocator.free(url);
        
        const response = try self.base.http_client.get(url, null);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.ExchangeError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const book_data = parsed.value.object;
        var order_book = try OrderBook.init(self.base.allocator, symbol);
        errdefer order_book.deinit(self.base.allocator);
        
        order_book.timestamp = std.time.milliTimestamp();
        
        if (book_data.get("bids")) |bids_array| {
            for (bids_array.array.items) |bid_item| {
                const bid = bid_item.array;
                const price = try std.fmt.parseFloat(f64, bid.items[0].string);
                const amount = try std.fmt.parseFloat(f64, bid.items[1].string);
                try order_book.bids.append(.{ price, amount });
            }
        }
        
        if (book_data.get("asks")) |asks_array| {
            for (asks_array.array.items) |ask_item| {
                const ask = ask_item.array;
                const price = try std.fmt.parseFloat(f64, ask.items[0].string);
                const amount = try std.fmt.parseFloat(f64, ask.items[1].string);
                try order_book.asks.append(.{ price, amount });
            }
        }
        
        return order_book;
    }
    
    pub fn fetchOHLCV(
        self: *CoinbaseExchange,
        symbol: []const u8,
        timeframe: types.TimeFrame,
        _: ?i64,
        _: ?u32,
    ) ![]OHLCV {
        self.base.throttle();
        
        const product_id = try self.symbolToCoinbase(symbol);
        defer self.base.allocator.free(product_id);
        
        const granularity = try self.timeframeToGranularity(timeframe);
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/products/{s}/candles?granularity={d}",
            .{ self.base.getApiUrl(), product_id, granularity },
        );
        defer self.base.allocator.free(url);
        
        const response = try self.base.http_client.get(url, null);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.ExchangeError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const candles_array = parsed.value.array;
        var ohlcv_list = std.ArrayList(OHLCV).init(self.base.allocator);
        
        for (candles_array.items) |candle_item| {
            const candle = candle_item.array;
            
            const ohlcv = OHLCV{
                .timestamp = candle.items[0].integer * 1000,
                .low = try std.fmt.parseFloat(f64, switch (candle.items[1]) {
                    .integer => |i| try std.fmt.allocPrint(self.base.allocator, "{d}", .{i}),
                    .float => |f| try std.fmt.allocPrint(self.base.allocator, "{d}", .{f}),
                    .string => |s| s,
                    else => "0",
                }),
                .high = try std.fmt.parseFloat(f64, switch (candle.items[2]) {
                    .integer => |i| try std.fmt.allocPrint(self.base.allocator, "{d}", .{i}),
                    .float => |f| try std.fmt.allocPrint(self.base.allocator, "{d}", .{f}),
                    .string => |s| s,
                    else => "0",
                }),
                .open = try std.fmt.parseFloat(f64, switch (candle.items[3]) {
                    .integer => |i| try std.fmt.allocPrint(self.base.allocator, "{d}", .{i}),
                    .float => |f| try std.fmt.allocPrint(self.base.allocator, "{d}", .{f}),
                    .string => |s| s,
                    else => "0",
                }),
                .close = try std.fmt.parseFloat(f64, switch (candle.items[4]) {
                    .integer => |i| try std.fmt.allocPrint(self.base.allocator, "{d}", .{i}),
                    .float => |f| try std.fmt.allocPrint(self.base.allocator, "{d}", .{f}),
                    .string => |s| s,
                    else => "0",
                }),
                .volume = try std.fmt.parseFloat(f64, switch (candle.items[5]) {
                    .integer => |i| try std.fmt.allocPrint(self.base.allocator, "{d}", .{i}),
                    .float => |f| try std.fmt.allocPrint(self.base.allocator, "{d}", .{f}),
                    .string => |s| s,
                    else => "0",
                }),
            };
            
            try ohlcv_list.append(ohlcv);
        }
        
        return try ohlcv_list.toOwnedSlice();
    }
    
    pub fn fetchTrades(self: *CoinbaseExchange, symbol: []const u8, _: ?i64, _: ?u32) ![]Trade {
        self.base.throttle();
        
        const product_id = try self.symbolToCoinbase(symbol);
        defer self.base.allocator.free(product_id);
        
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/products/{s}/trades",
            .{ self.base.getApiUrl(), product_id },
        );
        defer self.base.allocator.free(url);
        
        const response = try self.base.http_client.get(url, null);
        defer {
            var mut_response = response;
            mut_response.deinit(self.base.allocator);
        }
        
        if (response.status != 200) {
            return error.ExchangeError;
        }
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.base.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();
        
        const trades_array = parsed.value.array;
        var trades = std.ArrayList(Trade).init(self.base.allocator);
        
        for (trades_array.items) |trade_obj| {
            const trade_data = trade_obj.object;
            
            const trade_id = try std.fmt.allocPrint(self.base.allocator, "{d}", .{trade_data.get("trade_id").?.integer});
            const price = try std.fmt.parseFloat(f64, trade_data.get("price").?.string);
            const size = try std.fmt.parseFloat(f64, trade_data.get("size").?.string);
            const side_str = trade_data.get("side").?.string;
            const time_str = trade_data.get("time").?.string;
            
            const trade = Trade{
                .id = trade_id,
                .timestamp = std.time.milliTimestamp(),
                .datetime = try self.base.allocator.dupe(u8, time_str),
                .symbol = try self.base.allocator.dupe(u8, symbol),
                .type = .spot,
                .side = try self.base.allocator.dupe(u8, side_str),
                .price = price,
                .amount = size,
                .cost = price * size,
            };
            
            try trades.append(trade);
        }
        
        return try trades.toOwnedSlice();
    }
    
    pub fn fetchBalance(self: *CoinbaseExchange) !std.StringHashMap(Balance) {
        _ = self;
        return error.NotSupportedError;
    }
    
    pub fn createOrder(
        self: *CoinbaseExchange,
        symbol: []const u8,
        order_type: []const u8,
        side: []const u8,
        amount: f64,
        price: ?f64,
    ) !Order {
        _ = self;
        _ = symbol;
        _ = order_type;
        _ = side;
        _ = amount;
        _ = price;
        return error.NotSupportedError;
    }
    
    pub fn cancelOrder(self: *CoinbaseExchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotSupportedError;
    }
    
    pub fn fetchOrder(self: *CoinbaseExchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotSupportedError;
    }
    
    pub fn fetchOpenOrders(self: *CoinbaseExchange, symbol: ?[]const u8) ![]Order {
        _ = self;
        _ = symbol;
        return error.NotSupportedError;
    }
    
    pub fn fetchClosedOrders(
        self: *CoinbaseExchange,
        symbol: ?[]const u8,
        since: ?i64,
        limit: ?u32,
    ) ![]Order {
        _ = self;
        _ = symbol;
        _ = since;
        _ = limit;
        return error.NotSupportedError;
    }
    
    // Helper methods
    
    fn symbolToCoinbase(self: *CoinbaseExchange, symbol: []const u8) ![]u8 {
        // Convert BTC/USDT to BTC-USDT
        var result = std.ArrayList(u8).init(self.base.allocator);
        for (symbol) |c| {
            if (c == '/') {
                try result.append('-');
            } else {
                try result.append(c);
            }
        }
        return try result.toOwnedSlice();
    }
    
    fn timeframeToGranularity(self: *CoinbaseExchange, timeframe: types.TimeFrame) !u32 {
        _ = self;
        return switch (timeframe) {
            ._1m => 60,
            ._5m => 300,
            ._15m => 900,
            ._1h => 3600,
            ._6h => 21600,
            ._1d => 86400,
            else => 3600,
        };
    }
};
