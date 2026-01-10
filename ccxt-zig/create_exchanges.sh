#!/bin/bash

# Script to generate mid-tier exchange implementations
# This creates template files for all Phase 3.1 exchanges

EXCHANGES=(
    "bitfinex:Bitfinex:significant_digits"
    "gemini:Gemini:decimal_places"
    "bitget:Bitget:decimal_places"
    "bitmex:BitMEX:decimal_places"
    "deribit:Deribit:decimal_places"
    "mexc:MEXC:decimal_places"
    "bitstamp:Bitstamp:decimal_places"
    "poloniex:Poloniex:decimal_places"
    "bitrue:Bitrue:decimal_places"
    "phemex:Phemex:tick_size"
    "bingx:BingX:decimal_places"
    "xtcom:XT.COM:decimal_places"
    "coinex:CoinEx:decimal_places"
    "probit:ProBit:decimal_places"
    "woox:WOO_X:decimal_places"
    "bitmart:Bitmart:decimal_places"
    "ascendex:AscendEX:decimal_places"
)

echo "Creating ${#EXCHANGES[@]} mid-tier exchange implementations..."

for exchange_info in "${EXCHANGES[@]}"; do
    IFS=':' read -r id name precision <<< "$exchange_info"
    
    echo "Creating $name ($id)..."
    
    # Create exchange file with template
    cat > "src/exchanges/${id}.zig" << EOT
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

// $name Exchange Implementation
// Precision mode: $precision
// Exchange-specific tags: Implement based on $name API documentation
pub const ${name}Exchange = struct {
    allocator: std.mem.Allocator,
    base: exchange.BaseExchange,
    api_key: ?[]const u8,
    secret_key: ?[]const u8,
    testnet: bool,
    precision_config: precision_utils.ExchangePrecisionConfig,

    pub fn init(allocator: std.mem.Allocator, auth_config: auth.AuthConfig, testnet: bool) !*${name}Exchange {
        const self = try allocator.create(${name}Exchange);
        self.allocator = allocator;
        self.api_key = auth_config.apiKey;
        self.secret_key = auth_config.apiSecret;
        self.testnet = testnet;

                // $name uses $precision precision mode
                self.precision_config = .{
            .amount_mode = .${precision},
            .price_mode = .${precision},
            .default_amount_precision = 8,
            .default_price_precision = 8,
            .supports_tick_size = false,
        };

        const http_client = try http.HttpClient.init(allocator);
        const base_name = try allocator.dupe(u8, "${id}");
        const base_url = try allocator.dupe(u8, "https://api.${id}.com"); // Note: Verify this URL for ${name}
        const ws_url = try allocator.dupe(u8, "wss://ws.${id}.com"); // Note: Verify WebSocket URL for ${name}

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

    pub fn deinit(self: *${name}Exchange) void {
        if (self.api_key) |k| self.allocator.free(k);
        if (self.secret_key) |s| self.allocator.free(s);
        self.base.deinit();
        self.allocator.destroy(self);
    }

    // Template exchange - methods return error.NotImplemented
    // Full API implementation pending future development
    pub fn fetchMarkets(self: *${name}Exchange) ![]Market {
        _ = self;
        return error.NotImplemented;
    }

    pub fn fetchTicker(self: *${name}Exchange, symbol: []const u8) !Ticker {
        _ = self;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchOrderBook(self: *${name}Exchange, symbol: []const u8, limit: ?u32) !OrderBook {
        _ = self;
        _ = symbol;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchOHLCV(self: *${name}Exchange, symbol: []const u8, timeframe: []const u8, since: ?i64, limit: ?u32) ![]OHLCV {
        _ = self;
        _ = symbol;
        _ = timeframe;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchTrades(self: *${name}Exchange, symbol: []const u8, since: ?i64, limit: ?u32) ![]Trade {
        _ = self;
        _ = symbol;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }

    pub fn fetchBalance(self: *${name}Exchange) ![]Balance {
        _ = self;
        return error.NotImplemented;
    }

    pub fn createOrder(self: *${name}Exchange, symbol: []const u8, order_type: OrderType, side: OrderSide, amount: f64, price: ?f64, params: ?std.StringHashMap([]const u8)) !Order {
        _ = self;
        _ = symbol;
        _ = order_type;
        _ = side;
        _ = amount;
        _ = price;
        _ = params;
        return error.NotImplemented;
    }

    pub fn cancelOrder(self: *${name}Exchange, order_id: []const u8, symbol: ?[]const u8) !void {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchOrder(self: *${name}Exchange, order_id: []const u8, symbol: ?[]const u8) !Order {
        _ = self;
        _ = order_id;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchOpenOrders(self: *${name}Exchange, symbol: ?[]const u8) ![]Order {
        _ = self;
        _ = symbol;
        return error.NotImplemented;
    }

    pub fn fetchClosedOrders(self: *${name}Exchange, symbol: ?[]const u8, since: ?i64, limit: ?u32) ![]Order {
        _ = self;
        _ = symbol;
        _ = since;
        _ = limit;
        return error.NotImplemented;
    }
};

pub fn create(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*${name}Exchange {
    return ${name}Exchange.init(allocator, auth_config, false);
}

pub fn createTestnet(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) !*${name}Exchange {
    return ${name}Exchange.init(allocator, auth_config, true);
}
EOT

done

echo "All exchange templates created successfully!"
