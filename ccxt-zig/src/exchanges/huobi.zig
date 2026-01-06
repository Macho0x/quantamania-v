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

pub const HuobiExchange = struct {
    base: BaseExchange,
    
    pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*HuobiExchange {
        const config = ExchangeConfig{
            .apiUrl = "https://api.huobi.pro",
            .wsUrl = "wss://api.huobi.pro/ws",
            .rateLimit = 100, // 10 requests per second
            .enableRateLimit = true,
            .timeout = 30000,
            .verbose = false,
        };
        
        const exchange = try allocator.create(HuobiExchange);
        exchange.* = .{
            .base = try BaseExchange.init(allocator, "huobi", "Huobi", config, auth_config),
        };
        
        return exchange;
    }
    
    pub fn destroy(self: *HuobiExchange) void {
        self.base.deinit();
        self.base.allocator.destroy(self);
    }
    
    pub fn fetchMarkets(self: *HuobiExchange) ![]Market {
        self.base.throttle();
        
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/v1/common/symbols",
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
        
        var markets = std.ArrayList(Market).init(self.base.allocator);
        self.base.last_markets_fetch = std.time.milliTimestamp();
        return try markets.toOwnedSlice();
    }
    
    pub fn fetchTicker(self: *HuobiExchange, symbol: []const u8) !Ticker {
        self.base.throttle();
        
        const huobi_symbol = try self.symbolToHuobi(symbol);
        defer self.base.allocator.free(huobi_symbol);
        
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/market/detail/merged?symbol={s}",
            .{ self.base.getApiUrl(), huobi_symbol },
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
        
        return Ticker{
            .symbol = try self.base.allocator.dupe(u8, symbol),
            .timestamp = std.time.milliTimestamp(),
        };
    }
    
    pub fn fetchOrderBook(self: *HuobiExchange, symbol: []const u8, limit: ?u32) !OrderBook {
        self.base.throttle();
        
        const huobi_symbol = try self.symbolToHuobi(symbol);
        defer self.base.allocator.free(huobi_symbol);
        
        const depth_type = if (limit) |l| if (l <= 20) "step0" else "step1" else "step0";
        const url = try std.fmt.allocPrint(
            self.base.allocator,
            "{s}/market/depth?symbol={s}&type={s}",
            .{ self.base.getApiUrl(), huobi_symbol, depth_type },
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
        
        return try OrderBook.init(self.base.allocator, symbol);
    }
    
    pub fn fetchOHLCV(
        self: *HuobiExchange,
        symbol: []const u8,
        timeframe: types.TimeFrame,
        since: ?i64,
        limit: ?u32,
    ) ![]OHLCV {
        _ = symbol;
        _ = timeframe;
        _ = since;
        _ = limit;
        self.base.throttle();
        return &[_]OHLCV{};
    }
    
    pub fn fetchTrades(self: *HuobiExchange, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        _ = symbol;
        _ = since;
        _ = limit;
        self.base.throttle();
        return &[_]Trade{};
    }
    
    pub fn fetchBalance(self: *HuobiExchange) !std.StringHashMap(Balance) {
        _ = self;
        return error.NotSupportedError;
    }
    
    pub fn createOrder(
        self: *HuobiExchange,
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
    
    pub fn cancelOrder(self: *HuobiExchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotSupportedError;
    }
    
    pub fn fetchOrder(self: *HuobiExchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotSupportedError;
    }
    
    pub fn fetchOpenOrders(self: *HuobiExchange, symbol: ?[]const u8) ![]Order {
        _ = self;
        _ = symbol;
        return error.NotSupportedError;
    }
    
    pub fn fetchClosedOrders(
        self: *HuobiExchange,
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
    
    fn symbolToHuobi(self: *HuobiExchange, symbol: []const u8) ![]u8 {
        // Convert BTC/USDT to btcusdt (lowercase, no separator)
        var result = std.ArrayList(u8).init(self.base.allocator);
        for (symbol) |c| {
            if (c != '/') {
                try result.append(std.ascii.toLower(c));
            }
        }
        return try result.toOwnedSlice();
    }
};
