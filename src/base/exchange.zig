const std = @import("std");
const types = @import("../base/types.zig");
const errors = @import("../base/errors.zig");
const http = @import("../base/http.zig");
const auth = @import("../base/auth.zig");
const json = @import("../utils/json.zig");
const time = @import("../utils/time.zig");
const crypto = @import("../utils/crypto.zig");

// Exchange implementation interface (for registry)
pub const ExchangeImpl = *const fn (allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque;

// Base exchange functionality shared across all exchanges
pub const BaseExchange = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    api_url: []const u8,
    ws_url: []const u8,
    http_client: http.HttpClient,
    auth_config: auth.AuthConfig,

    // Market cache
    markets: ?[]Market,
    last_markets_fetch: i64,
    markets_cache_ttl_ms: i64 = 3600000, // 1 hour default

    // Rate limiting
    rate_limit: u32 = 10, // requests per second
    rate_limit_window_ms: i64 = 60000,
    request_counter: u32 = 0,
    rate_limit_reset: i64 = 0,

    // Version and headers
    version: []const u8 = "v1",
    user_agent: []const u8 = "CCXT-Zig/0.1.0",
    headers: std.StringHashMap([]const u8),

    // Parser
    json_parser: json.JsonParser,

    pub fn deinit(self: *BaseExchange) void {
        if (self.markets) |m| {
            for (m) |*market| market.deinit(self.allocator);
            self.allocator.free(m);
        }

        self.http_client.deinit();

        self.allocator.free(self.name);
        self.allocator.free(self.api_url);
        self.allocator.free(self.ws_url);

        var header_iter = self.headers.iterator();
        while (header_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }

    // Rate limiting check
    pub fn checkRateLimit(self: *BaseExchange) !void {
        const now = time.TimeUtils.now();

        if (now >= self.rate_limit_reset) {
            // Reset counter
            self.request_counter = 0;
            self.rate_limit_reset = now + self.rate_limit_window_ms;
        }

        if (self.request_counter >= self.rate_limit) {
            const wait_ms = self.rate_limit_reset - now;
            return error.RateLimitError;
        }

        self.request_counter += 1;
    }

    // Market cache management
    pub fn isMarketsCacheValid(self: *BaseExchange) bool {
        if (self.markets == null) return false;
        const now = time.TimeUtils.now();
        return now - self.last_markets_fetch < self.markets_cache_ttl_ms;
    }

    pub fn invalidateMarketsCache(self: *BaseExchange) void {
        if (self.markets) |m| {
            for (m) |*market| market.deinit(self.allocator);
            self.allocator.free(m);
            self.markets = null;
        }
    }

    // Symbol normalization (BTC/USDT -> exchange format)
    pub fn normalizeSymbol(self: *BaseExchange, symbol: []const u8) []const u8 {
        _ = self;
        return symbol;
    }

    // Denormalize symbol (exchange format -> BTC/USDT)
    pub fn denormalizeSymbol(self: *BaseExchange, symbol: []const u8) []const u8 {
        _ = self;
        return symbol;
    }

    // Find market by symbol
    pub fn findMarket(self: *BaseExchange, symbol: []const u8) ?*Market {
        if (self.markets) |markets| {
            for (markets) |*market| {
                if (std.mem.eql(u8, market.symbol, symbol)) {
                    return market;
                }
            }
        }
        return null;
    }

    // Find market by ID
    pub fn findMarketById(self: *BaseExchange, id: []const u8) ?*Market {
        if (self.markets) |markets| {
            for (markets) |*market| {
                if (std.mem.eql(u8, market.id, id)) {
                    return market;
                }
            }
        }
        return null;
    }

    // Parse timestamp
    pub fn parseTimestamp(self: *BaseExchange, timestamp: ?std.json.Value, default: i64) i64 {
        return switch (timestamp orelse .{ .integer = default }) {
            .integer => |ts| ts,
            .float => |ts| @intFromFloat(ts),
            .string => |s| std.fmt.parseInt(i64, s, 10) catch default,
            else => default,
        };
    }

    // Parse datetime string
    pub fn parseDatetime(self: *BaseExchange, allocator: std.mem.Allocator, timestamp: i64) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{d}", .{timestamp});
    }
};

// Import models at end to avoid circular dependencies
const Market = @import("market.zig").Market;
const Ticker = @import("ticker.zig").Ticker;
const OrderBook = @import("orderbook.zig").OrderBook;
const Order = @import("order.zig").Order;
const Balance = @import("balance.zig").Balance;
const Trade = @import("trade.zig").Trade;
const OHLCV = @import("ohlcv.zig").OHLCV;
const Position = @import("position.zig").Position;
