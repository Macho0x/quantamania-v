const std = @import("std");
const exchange = @import("../base/exchange.zig");
const auth = @import("../base/auth.zig");
const http = @import("../base/http.zig");
const json = @import("../utils/json.zig");
const precision_utils = @import("../utils/precision.zig");

// Import models
const Market = @import("../models/market.zig").Market;
const Ticker = @import("../models/ticker.zig").Ticker;
const OrderBook = @import("../models/orderbook.zig").OrderBook;
const Order = @import("../models/order.zig").Order;
const OrderType = @import("../models/order.zig").OrderType;
const OrderSide = @import("../models/order.zig").OrderSide;
const Balance = @import("../models/balance.zig").Balance;
const Trade = @import("../models/trade.zig").Trade;
const OHLCV = @import("../models/ohlcv.zig").OHLCV;

// Hyperliquid Exchange (DEX / perpetuals)
// Documentation: https://hyperliquid.gitbook.io/hyperliquid-docs/
pub const Hyperliquid = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    wallet_address: ?[]const u8,
    wallet_private_key: ?[]const u8,
    testnet: bool,
    precision_config: precision_utils.ExchangePrecisionConfig,

    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig, testnet: bool) !*Hyperliquid {
        const self = try allocator.create(Hyperliquid);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.wallet_address = auth_config.wallet_address;
        self.wallet_private_key = auth_config.wallet_private_key;
        self.testnet = testnet;
        self.precision_config = precision_utils.ExchangePrecisionConfig.dex();

        var http_client = try http.HttpClient.init(allocator);
        errdefer http_client.deinit();

        const base_name = try allocator.dupe(u8, "hyperliquid");
        const base_url = try allocator.dupe(u8, if (testnet) "https://api.hyperliquid.xyz" else "https://api.hyperliquid.xyz");
        const ws_url = try allocator.dupe(u8, "wss://api.hyperliquid.xyz/ws");

        self.base = exchange.BaseExchange{
            .allocator = allocator,
            .name = base_name,
            .api_url = base_url,
            .ws_url = ws_url,
            .http_client = http_client,
            .auth_config = auth_config,
            .markets = null,
            .last_markets_fetch = 0,
            .rate_limit = 50,
            .rate_limit_window_ms = 1000,
            .request_counter = 0,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .json_parser = json.JsonParser.init(allocator),
        };

        try self.base.headers.put(try allocator.dupe(u8, "User-Agent"), try allocator.dupe(u8, self.base.user_agent));
        try self.base.headers.put(try allocator.dupe(u8, "Accept"), try allocator.dupe(u8, "application/json"));

        return self;
    }

    pub fn deinit(self: *Hyperliquid) void {
        if (self.wallet_address) |w| self.allocator.free(w);
        if (self.wallet_private_key) |w| self.allocator.free(w);
        self.base.deinit();
        self.allocator.destroy(self);
    }

    pub fn fetchMarkets(self: *Hyperliquid) ![]Market {
        _ = self;
        return error.NotImplemented;
    }

    pub fn fetchTicker(self: *Hyperliquid, symbol: []const u8) !Ticker {
        _ = self;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchOrderBook(self: *Hyperliquid, symbol: []const u8, limit: ?u32) !OrderBook {
        _ = self;
        _ = symbol;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchOHLCV(self: *Hyperliquid, symbol: []const u8, timeframe: []const u8, since: ?i64, limit: ?u32) ![]OHLCV {
        _ = self;
        _ = symbol;
        _ = timeframe;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchTrades(self: *Hyperliquid, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        _ = self;
        _ = symbol;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchBalance(self: *Hyperliquid) ![]Balance {
        _ = self;
        return error.NotImplemented;
    }

    pub fn createOrder(self: *Hyperliquid, symbol: []const u8, order_type: OrderType, side: OrderSide, amount: f64, price: ?f64, params: ?std.StringHashMap([]const u8)) !Order {
        _ = self;
        _ = symbol;
        _ = order_type;
        _ = side;
        _ = amount;
        _ = price;
        _ = params;
        return error.NotImplemented;
    }

    pub fn cancelOrder(self: *Hyperliquid, order_id: []const u8, symbol: ?[]const u8) !void {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchOrder(self: *Hyperliquid, order_id: []const u8, symbol: ?[]const u8) !Order {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchOpenOrders(self: *Hyperliquid, symbol: ?[]const u8) ![]Order {
        _ = self;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchClosedOrders(self: *Hyperliquid, symbol: ?[]const u8, since: ?i64, limit: ?u32) ![]Order {
        _ = self;
        _ = symbol;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }
};

pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*Hyperliquid {
    return Hyperliquid.init(allocator, auth_config, false);
}

pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*Hyperliquid {
    return Hyperliquid.init(allocator, auth_config, true);
}
