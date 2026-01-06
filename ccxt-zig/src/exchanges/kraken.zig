const std = @import("std");
const BaseExchange = @import("../base/exchange.zig").BaseExchange;
const ExchangeConfig = @import("../base/exchange.zig").ExchangeConfig;
const OrderBook = @import("../base/exchange.zig").OrderBook;
const auth = @import("../base/auth.zig");
const types = @import("../base/types.zig");
const Market = @import("../models/market.zig").Market;
const Ticker = @import("../models/ticker.zig").Ticker;
const Order = @import("../models/order.zig").Order;
const OrderType = @import("../models/order.zig").OrderType;
const OrderSide = @import("../models/order.zig").OrderSide;
const OrderStatus = @import("../models/order.zig").OrderStatus;
const Trade = @import("../models/trade.zig").Trade;
const OHLCV = @import("../models/ohlcv.zig").OHLCV;
const Balance = @import("../models/balance.zig").Balance;

pub const KrakenExchange = struct {
    base: BaseExchange,
    
    pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*KrakenExchange {
        const config = ExchangeConfig{
            .apiUrl = "https://api.kraken.com",
            .wsUrl = "wss://ws.kraken.com",
            .rateLimit = 1500, // Tier 2: 20 calls per second
            .enableRateLimit = true,
            .timeout = 30000,
            .verbose = false,
        };
        
        const exchange = try allocator.create(KrakenExchange);
        exchange.* = .{
            .base = try BaseExchange.init(allocator, "kraken", "Kraken", config, auth_config),
        };
        
        return exchange;
    }
    
    pub fn destroy(self: *KrakenExchange) void {
        self.base.deinit();
        self.base.allocator.destroy(self);
    }
    
    pub fn fetchMarkets(self: *KrakenExchange) ![]Market {
        self.base.throttle();
        
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/0/public/AssetPairs",
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
        
        const root = parsed.value.object;
        const result = root.get("result").?.object;
        
        var markets = std.ArrayList(Market).init(self.base.allocator);
        errdefer {
            for (markets.items) |*market| {
                market.deinit(self.base.allocator);
            }
            markets.deinit();
        }
        
        var it = result.iterator();
        while (it.next()) |entry| {
            const pair_id = entry.key_ptr.*;
            const pair_data = entry.value_ptr.*.object;
            
            // Skip dark pool pairs
            if (std.mem.endsWith(u8, pair_id, ".d")) continue;
            
            const base = pair_data.get("base").?.string;
            const quote = pair_data.get("quote").?.string;
            
            // Normalize XBT to BTC
            const normalized_base = if (std.mem.eql(u8, base, "XBT"))
                try self.base.allocator.dupe(u8, "BTC")
            else
                try self.base.allocator.dupe(u8, base);
            
            const normalized_quote = if (std.mem.eql(u8, quote, "XBT"))
                try self.base.allocator.dupe(u8, "BTC")
            else
                try self.base.allocator.dupe(u8, quote);
            
            const market = Market{
                .id = try self.base.allocator.dupe(u8, pair_id),
                .symbol = try std.fmt.allocPrint(
                    self.base.allocator,
                    "{s}/{s}",
                    .{ normalized_base, normalized_quote },
                ),
                .base = normalized_base,
                .quote = normalized_quote,
                .baseId = try self.base.allocator.dupe(u8, base),
                .quoteId = try self.base.allocator.dupe(u8, quote),
                .active = true,
                .spot = true,
                .margin = pair_data.get("margin_call").?.integer > 0,
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
    
    pub fn fetchTicker(self: *KrakenExchange, symbol: []const u8) !Ticker {
        self.base.throttle();
        
        const kraken_pair = try self.symbolToKraken(symbol);
        defer self.base.allocator.free(kraken_pair);
        
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/0/public/Ticker?pair={s}",
            .{ self.base.getApiUrl(), kraken_pair },
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
        
        const root = parsed.value.object;
        const result = root.get("result").?.object;
        
        var it = result.iterator();
        const first_entry = it.next().?;
        const ticker_data = first_entry.value_ptr.*.object;
        
        return Ticker{
            .symbol = try self.base.allocator.dupe(u8, symbol),
            .timestamp = std.time.milliTimestamp(),
            .high = try std.fmt.parseFloat(f64, ticker_data.get("h").?.array.items[1].string),
            .low = try std.fmt.parseFloat(f64, ticker_data.get("l").?.array.items[1].string),
            .bid = try std.fmt.parseFloat(f64, ticker_data.get("b").?.array.items[0].string),
            .ask = try std.fmt.parseFloat(f64, ticker_data.get("a").?.array.items[0].string),
            .last = try std.fmt.parseFloat(f64, ticker_data.get("c").?.array.items[0].string),
            .open = try std.fmt.parseFloat(f64, ticker_data.get("o").?.string),
            .baseVolume = try std.fmt.parseFloat(f64, ticker_data.get("v").?.array.items[1].string),
            .vwap = try std.fmt.parseFloat(f64, ticker_data.get("p").?.array.items[1].string),
        };
    }
    
    pub fn fetchOrderBook(self: *KrakenExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        self.base.throttle();
        
        const kraken_pair = try self.symbolToKraken(symbol);
        defer self.base.allocator.free(kraken_pair);
        
        const count = limit orelse 100;
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/0/public/Depth?pair={s}&count={d}",
            .{ self.base.getApiUrl(), kraken_pair, count },
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
        
        const root = parsed.value.object;
        const result = root.get("result").?.object;
        
        var it = result.iterator();
        const first_entry = it.next().?;
        const depth_data = first_entry.value_ptr.*.object;
        
        var order_book = try OrderBook.init(self.base.allocator, symbol);
        errdefer order_book.deinit(self.base.allocator);
        
        order_book.timestamp = std.time.milliTimestamp();
        
        if (depth_data.get("bids")) |bids_array| {
            for (bids_array.array.items) |bid_item| {
                const bid = bid_item.array;
                const price = try std.fmt.parseFloat(f64, bid.items[0].string);
                const amount = try std.fmt.parseFloat(f64, bid.items[1].string);
                try order_book.bids.append(.{ price, amount });
            }
        }
        
        if (depth_data.get("asks")) |asks_array| {
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
        self: *KrakenExchange,
        symbol: []const u8,
        timeframe: types.TimeFrame,
        _: ?i64,
        _: ?u32,
    ) ![]OHLCV {
        self.base.throttle();
        
        const kraken_pair = try self.symbolToKraken(symbol);
        defer self.base.allocator.free(kraken_pair);
        
        const interval = try self.timeframeToInterval(timeframe);
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/0/public/OHLC?pair={s}&interval={d}",
            .{ self.base.getApiUrl(), kraken_pair, interval },
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
        
        const root = parsed.value.object;
        const result = root.get("result").?.object;
        
        var it = result.iterator();
        var ohlcv_array: std.json.Array = undefined;
        while (it.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, "last")) continue;
            ohlcv_array = entry.value_ptr.*.array;
            break;
        }
        
        var ohlcv_list = std.ArrayList(OHLCV).init(self.base.allocator);
        
        for (ohlcv_array.items) |ohlcv_item| {
            const candle = ohlcv_item.array;
            
            const ohlcv = OHLCV{
                .timestamp = candle.items[0].integer * 1000, // Convert to milliseconds
                .open = try std.fmt.parseFloat(f64, candle.items[1].string),
                .high = try std.fmt.parseFloat(f64, candle.items[2].string),
                .low = try std.fmt.parseFloat(f64, candle.items[3].string),
                .close = try std.fmt.parseFloat(f64, candle.items[4].string),
                .volume = try std.fmt.parseFloat(f64, candle.items[6].string),
            };
            
            try ohlcv_list.append(ohlcv);
        }
        
        return try ohlcv_list.toOwnedSlice();
    }
    
    pub fn fetchTrades(
        self: *KrakenExchange,
        symbol: []const u8,
        _: ?i64,
        _: ?u32,
    ) ![]Trade {
        self.base.throttle();
        
        const kraken_pair = try self.symbolToKraken(symbol);
        defer self.base.allocator.free(kraken_pair);
        
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/0/public/Trades?pair={s}",
            .{ self.base.getApiUrl(), kraken_pair },
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
        
        const root = parsed.value.object;
        const result = root.get("result").?.object;
        
        var it = result.iterator();
        var trades_array: std.json.Array = undefined;
        while (it.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, "last")) continue;
            trades_array = entry.value_ptr.*.array;
            break;
        }
        
        var trades = std.ArrayList(Trade).init(self.base.allocator);
        
        for (trades_array.items) |trade_item| {
            const trade_data = trade_item.array;
            
            const price = try std.fmt.parseFloat(f64, trade_data.items[0].string);
            const amount = try std.fmt.parseFloat(f64, trade_data.items[1].string);
            const timestamp_float = try std.fmt.parseFloat(f64, trade_data.items[2].string);
            const timestamp: i64 = @intFromFloat(timestamp_float * 1000);
            const side_char = trade_data.items[3].string;
            
            const trade = Trade{
                .id = try std.fmt.allocPrint(self.base.allocator, "{d}", .{timestamp}),
                .timestamp = timestamp,
                .datetime = try std.fmt.allocPrint(self.base.allocator, "{d}", .{timestamp}),
                .symbol = try self.base.allocator.dupe(u8, symbol),
                .type = .spot,
                .side = try self.base.allocator.dupe(u8, if (std.mem.eql(u8, side_char, "b")) "buy" else "sell"),
                .price = price,
                .amount = amount,
                .cost = price * amount,
            };
            
            try trades.append(trade);
        }
        
        return try trades.toOwnedSlice();
    }
    
    pub fn fetchBalance(self: *KrakenExchange) !std.StringHashMap(Balance) {
        _ = self;
        return error.NotSupportedError;
    }
    
    pub fn createOrder(
        self: *KrakenExchange,
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
    
    pub fn cancelOrder(self: *KrakenExchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotSupportedError;
    }
    
    pub fn fetchOrder(self: *KrakenExchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotSupportedError;
    }
    
    pub fn fetchOpenOrders(self: *KrakenExchange, symbol: ?[]const u8) ![]Order {
        _ = self;
        _ = symbol;
        return error.NotSupportedError;
    }
    
    pub fn fetchClosedOrders(
        self: *KrakenExchange,
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
    
    fn symbolToKraken(self: *KrakenExchange, symbol: []const u8) ![]u8 {
        // Convert BTC/USDT to XXBTZUSDT format (simplified)
        var result = std.ArrayList(u8).init(self.base.allocator);
        for (symbol) |c| {
            if (c != '/') {
                try result.append(c);
            }
        }
        return try result.toOwnedSlice();
    }
    
    fn timeframeToInterval(self: *KrakenExchange, timeframe: types.TimeFrame) !u32 {
        _ = self;
        return switch (timeframe) {
            ._1m => 1,
            ._5m => 5,
            ._15m => 15,
            ._30m => 30,
            ._1h => 60,
            ._4h => 240,
            ._1d => 1440,
            ._1w => 10080,
            else => 60,
        };
    }
};
