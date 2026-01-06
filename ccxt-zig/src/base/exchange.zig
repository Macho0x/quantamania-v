const std = @import("std");
const types = @import("types.zig");
const auth = @import("auth.zig");
const http = @import("http.zig");
const errors = @import("errors.zig");
const Market = @import("../models/market.zig").Market;
const Ticker = @import("../models/ticker.zig").Ticker;
const Order = @import("../models/order.zig").Order;
const Trade = @import("../models/trade.zig").Trade;
const OHLCV = @import("../models/ohlcv.zig").OHLCV;
const Balance = @import("../models/balance.zig").Balance;

pub const OrderBook = struct {
    symbol: []const u8,
    timestamp: types.Timestamp,
    datetime: []const u8,
    nonce: ?u64 = null,
    bids: std.ArrayList([2]f64),
    asks: std.ArrayList([2]f64),
    
    pub fn init(allocator: std.mem.Allocator, symbol: []const u8) !OrderBook {
        return .{
            .symbol = try allocator.dupe(u8, symbol),
            .timestamp = std.time.milliTimestamp(),
            .datetime = "",
            .bids = std.ArrayList([2]f64).init(allocator),
            .asks = std.ArrayList([2]f64).init(allocator),
        };
    }
    
    pub fn deinit(self: *OrderBook, allocator: std.mem.Allocator) void {
        allocator.free(self.symbol);
        if (self.datetime.len > 0) allocator.free(self.datetime);
        self.bids.deinit();
        self.asks.deinit();
    }
};

pub const ExchangeConfig = struct {
    apiUrl: []const u8,
    wsUrl: ?[]const u8 = null,
    testApiUrl: ?[]const u8 = null,
    testWsUrl: ?[]const u8 = null,
    rateLimit: u32 = 1000,
    enableTestnet: bool = false,
    enableRateLimit: bool = true,
    timeout: u64 = 30000,
    verbose: bool = false,
    marketsCacheTtl: i64 = 3600000, // 1 hour
};

pub const BaseExchange = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    name: []const u8,
    config: ExchangeConfig,
    auth_config: auth.AuthConfig,
    http_client: *http.HttpClient,
    markets: ?std.StringHashMap(Market) = null,
    last_markets_fetch: i64 = 0,
    rate_limit_state: RateLimitState,
    
    pub const RateLimitState = struct {
        last_request_time: i64 = 0,
        request_count: u32 = 0,
        window_start: i64 = 0,
    };
    
    pub fn init(
        allocator: std.mem.Allocator,
        id: []const u8,
        name: []const u8,
        config: ExchangeConfig,
        auth_config: auth.AuthConfig,
    ) !BaseExchange {
        const http_client = try allocator.create(http.HttpClient);
        http_client.* = try http.HttpClient.init(allocator);
        http_client.setTimeout(config.timeout);
        http_client.enableLogging(config.verbose);
        
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .config = config,
            .auth_config = auth_config,
            .http_client = http_client,
            .markets = null,
            .rate_limit_state = .{},
        };
    }
    
    pub fn deinit(self: *BaseExchange) void {
        self.allocator.free(self.id);
        self.allocator.free(self.name);
        
        if (self.markets) |*markets| {
            var iterator = markets.iterator();
            while (iterator.next()) |entry| {
                var market = entry.value_ptr.*;
                market.deinit(self.allocator);
                self.allocator.free(entry.key_ptr.*);
            }
            markets.deinit();
        }
        
        self.http_client.deinit();
        self.allocator.destroy(self.http_client);
    }
    
    pub fn getApiUrl(self: *const BaseExchange) []const u8 {
        if (self.config.enableTestnet and self.config.testApiUrl != null) {
            return self.config.testApiUrl.?;
        }
        return self.config.apiUrl;
    }
    
    pub fn throttle(self: *BaseExchange) void {
        if (!self.config.enableRateLimit) return;
        
        const now = std.time.milliTimestamp();
        const elapsed = now - self.rate_limit_state.last_request_time;
        
        if (elapsed < self.config.rateLimit) {
            const sleep_ms = self.config.rateLimit - elapsed;
            std.time.sleep(@intCast(sleep_ms * std.time.ns_per_ms));
        }
        
        self.rate_limit_state.last_request_time = std.time.milliTimestamp();
    }
    
    pub fn shouldRefreshMarkets(self: *const BaseExchange) bool {
        const now = std.time.milliTimestamp();
        return self.markets == null or 
               (now - self.last_markets_fetch) > self.config.marketsCacheTtl;
    }
};

pub const ExchangeInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    
    pub const VTable = struct {
        fetchMarkets: *const fn (ptr: *anyopaque) anyerror![]Market,
        fetchTicker: *const fn (ptr: *anyopaque, symbol: []const u8) anyerror!Ticker,
        fetchOrderBook: *const fn (ptr: *anyopaque, symbol: []const u8, limit: ?u32) anyerror!OrderBook,
        fetchOHLCV: *const fn (ptr: *anyopaque, symbol: []const u8, timeframe: types.TimeFrame, since: ?i64, limit: ?u32) anyerror![]OHLCV,
        fetchTrades: *const fn (ptr: *anyopaque, symbol: []const u8, since: ?i64, limit: ?u32) anyerror![]Trade,
        fetchBalance: *const fn (ptr: *anyopaque) anyerror!std.StringHashMap(Balance),
        createOrder: *const fn (ptr: *anyopaque, symbol: []const u8, order_type: []const u8, side: []const u8, amount: f64, price: ?f64) anyerror!Order,
        cancelOrder: *const fn (ptr: *anyopaque, order_id: []const u8, symbol: ?[]const u8) anyerror!Order,
        fetchOrder: *const fn (ptr: *anyopaque, order_id: []const u8, symbol: ?[]const u8) anyerror!Order,
        fetchOpenOrders: *const fn (ptr: *anyopaque, symbol: ?[]const u8) anyerror![]Order,
        fetchClosedOrders: *const fn (ptr: *anyopaque, symbol: ?[]const u8, since: ?i64, limit: ?u32) anyerror![]Order,
    };
    
    pub fn fetchMarkets(self: ExchangeInterface) ![]Market {
        return self.vtable.fetchMarkets(self.ptr);
    }
    
    pub fn fetchTicker(self: ExchangeInterface, symbol: []const u8) !Ticker {
        return self.vtable.fetchTicker(self.ptr, symbol);
    }
    
    pub fn fetchOrderBook(self: ExchangeInterface, symbol: []const u8, limit: ?u32) !OrderBook {
        return self.vtable.fetchOrderBook(self.ptr, symbol, limit);
    }
    
    pub fn fetchOHLCV(self: ExchangeInterface, symbol: []const u8, timeframe: types.TimeFrame, since: ?i64, limit: ?u32) ![]OHLCV {
        return self.vtable.fetchOHLCV(self.ptr, symbol, timeframe, since, limit);
    }
    
    pub fn fetchTrades(self: ExchangeInterface, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        return self.vtable.fetchTrades(self.ptr, symbol, since, limit);
    }
    
    pub fn fetchBalance(self: ExchangeInterface) !std.StringHashMap(Balance) {
        return self.vtable.fetchBalance(self.ptr);
    }
    
    pub fn createOrder(self: ExchangeInterface, symbol: []const u8, order_type: []const u8, side: []const u8, amount: f64, price: ?f64) !Order {
        return self.vtable.createOrder(self.ptr, symbol, order_type, side, amount, price);
    }
    
    pub fn cancelOrder(self: ExchangeInterface, order_id: []const u8, symbol: ?[]const u8) !Order {
        return self.vtable.cancelOrder(self.ptr, order_id, symbol);
    }
    
    pub fn fetchOrder(self: ExchangeInterface, order_id: []const u8, symbol: ?[]const u8) !Order {
        return self.vtable.fetchOrder(self.ptr, order_id, symbol);
    }
    
    pub fn fetchOpenOrders(self: ExchangeInterface, symbol: ?[]const u8) ![]Order {
        return self.vtable.fetchOpenOrders(self.ptr, symbol);
    }
    
    pub fn fetchClosedOrders(self: ExchangeInterface, symbol: ?[]const u8, since: ?i64, limit: ?u32) ![]Order {
        return self.vtable.fetchClosedOrders(self.ptr, symbol, since, limit);
    }
};
