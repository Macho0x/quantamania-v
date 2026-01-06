const std = @import("std");

// Base
pub const types = @import("base/types.zig");
pub const auth = @import("base/auth.zig");
pub const http = @import("base/http.zig");
pub const errors = @import("base/errors.zig");
pub const exchange = @import("base/exchange.zig");

// Models
pub const Market = @import("models/market.zig").Market;
pub const Ticker = @import("models/ticker.zig").Ticker;
pub const Order = @import("models/order.zig").Order;
pub const Trade = @import("models/trade.zig").Trade;
pub const OHLCV = @import("models/ohlcv.zig").OHLCV;
pub const Balance = @import("models/balance.zig").Balance;

// Exchanges
pub const binance = @import("exchanges/binance.zig");
pub const kraken = @import("exchanges/kraken.zig");
pub const coinbase = @import("exchanges/coinbase.zig");
pub const bybit = @import("exchanges/bybit.zig");
pub const okx = @import("exchanges/okx.zig");
pub const gate = @import("exchanges/gate.zig");
pub const huobi = @import("exchanges/huobi.zig");

pub const ExchangeType = enum {
    binance,
    kraken,
    coinbase,
    bybit,
    okx,
    gate,
    huobi,
    
    pub fn fromString(name: []const u8) ?ExchangeType {
        if (std.mem.eql(u8, name, "binance")) return .binance;
        if (std.mem.eql(u8, name, "kraken")) return .kraken;
        if (std.mem.eql(u8, name, "coinbase")) return .coinbase;
        if (std.mem.eql(u8, name, "bybit")) return .bybit;
        if (std.mem.eql(u8, name, "okx")) return .okx;
        if (std.mem.eql(u8, name, "gate")) return .gate;
        if (std.mem.eql(u8, name, "huobi")) return .huobi;
        return null;
    }
    
    pub fn toString(self: ExchangeType) []const u8 {
        return switch (self) {
            .binance => "binance",
            .kraken => "kraken",
            .coinbase => "coinbase",
            .bybit => "bybit",
            .okx => "okx",
            .gate => "gate",
            .huobi => "huobi",
        };
    }
};

pub const ExchangeRegistry = struct {
    allocator: std.mem.Allocator,
    exchanges: std.StringHashMap(*anyopaque),
    exchange_types: std.StringHashMap(ExchangeType),
    
    pub fn init(allocator: std.mem.Allocator) ExchangeRegistry {
        return .{
            .allocator = allocator,
            .exchanges = std.StringHashMap(*anyopaque).init(allocator),
            .exchange_types = std.StringHashMap(ExchangeType).init(allocator),
        };
    }
    
    pub fn deinit(self: *ExchangeRegistry) void {
        var it = self.exchanges.iterator();
        while (it.next()) |entry| {
            const exchange_type = self.exchange_types.get(entry.key_ptr.*).?;
            switch (exchange_type) {
                .binance => {
                    const ex: *binance.BinanceExchange = @ptrCast(@alignCast(entry.value_ptr.*));
                    ex.destroy();
                },
                .kraken => {
                    const ex: *kraken.KrakenExchange = @ptrCast(@alignCast(entry.value_ptr.*));
                    ex.destroy();
                },
                .coinbase => {
                    const ex: *coinbase.CoinbaseExchange = @ptrCast(@alignCast(entry.value_ptr.*));
                    ex.destroy();
                },
                .bybit => {
                    const ex: *bybit.BybitExchange = @ptrCast(@alignCast(entry.value_ptr.*));
                    ex.destroy();
                },
                .okx => {
                    const ex: *okx.OKXExchange = @ptrCast(@alignCast(entry.value_ptr.*));
                    ex.destroy();
                },
                .gate => {
                    const ex: *gate.GateExchange = @ptrCast(@alignCast(entry.value_ptr.*));
                    ex.destroy();
                },
                .huobi => {
                    const ex: *huobi.HuobiExchange = @ptrCast(@alignCast(entry.value_ptr.*));
                    ex.destroy();
                },
            }
            self.allocator.free(entry.key_ptr.*);
        }
        
        var type_it = self.exchange_types.iterator();
        while (type_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        
        self.exchanges.deinit();
        self.exchange_types.deinit();
    }
    
    pub fn registerExchange(
        self: *ExchangeRegistry,
        name: []const u8,
        exchange_type: ExchangeType,
        exchange_ptr: *anyopaque,
    ) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        
        try self.exchanges.put(name_copy, exchange_ptr);
        
        const type_name_copy = try self.allocator.dupe(u8, name);
        try self.exchange_types.put(type_name_copy, exchange_type);
    }
    
    pub fn getExchange(self: *ExchangeRegistry, name: []const u8, comptime T: type) ?*T {
        const ptr = self.exchanges.get(name) orelse return null;
        return @ptrCast(@alignCast(ptr));
    }
    
    pub fn hasExchange(self: *const ExchangeRegistry, name: []const u8) bool {
        return self.exchanges.contains(name);
    }
    
    pub fn listExchanges(self: *const ExchangeRegistry) ![][]const u8 {
        var list = std.ArrayList([]const u8).init(self.allocator);
        
        var it = self.exchanges.keyIterator();
        while (it.next()) |key| {
            try list.append(key.*);
        }
        
        return try list.toOwnedSlice();
    }
};

pub fn createExchange(
    allocator: std.mem.Allocator,
    exchange_type: ExchangeType,
    auth_config: auth.AuthConfig,
) !*anyopaque {
    return switch (exchange_type) {
        .binance => @ptrCast(try binance.BinanceExchange.create(allocator, auth_config)),
        .kraken => @ptrCast(try kraken.KrakenExchange.create(allocator, auth_config)),
        .coinbase => @ptrCast(try coinbase.CoinbaseExchange.create(allocator, auth_config)),
        .bybit => @ptrCast(try bybit.BybitExchange.create(allocator, auth_config)),
        .okx => @ptrCast(try okx.OKXExchange.create(allocator, auth_config)),
        .gate => @ptrCast(try gate.GateExchange.create(allocator, auth_config)),
        .huobi => @ptrCast(try huobi.HuobiExchange.create(allocator, auth_config)),
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("CCXT Zig - Phase 2: Major Exchanges Implementation\n", .{});
    std.debug.print("==================================================\n\n", .{});
    
    // Create exchange registry
    var registry = ExchangeRegistry.init(allocator);
    defer registry.deinit();
    
    // Create auth config (empty for public endpoints)
    const auth_config = auth.AuthConfig{};
    
    // Register all exchanges
    std.debug.print("Registering exchanges...\n", .{});
    
    const exchanges = [_]ExchangeType{
        .binance,
        .kraken,
        .coinbase,
        .bybit,
        .okx,
        .gate,
        .huobi,
    };
    
    for (exchanges) |exchange_type| {
        const name = exchange_type.toString();
        const exchange_ptr = try createExchange(allocator, exchange_type, auth_config);
        try registry.registerExchange(name, exchange_type, exchange_ptr);
        std.debug.print("  ✓ {s}\n", .{name});
    }
    
    std.debug.print("\nRegistered {} exchanges\n", .{exchanges.len});
    
    // Example: Fetch ticker from Binance
    std.debug.print("\n--- Example: Binance Ticker ---\n", .{});
    if (registry.getExchange("binance", binance.BinanceExchange)) |binance_ex| {
        const ticker = binance_ex.fetchTicker("BTC/USDT") catch |err| {
            std.debug.print("Error fetching ticker: {}\n", .{err});
            return;
        };
        defer {
            var mut_ticker = ticker;
            mut_ticker.deinit(allocator);
        }
        
        std.debug.print("Symbol: {s}\n", .{ticker.symbol});
        std.debug.print("Last: {?d:.2}\n", .{ticker.last});
        std.debug.print("Bid: {?d:.2}\n", .{ticker.bid});
        std.debug.print("Ask: {?d:.2}\n", .{ticker.ask});
        std.debug.print("Volume: {?d:.2}\n", .{ticker.baseVolume});
    }
    
    std.debug.print("\nAll exchanges initialized successfully!\n", .{});
}

test "exchange registry" {
    const allocator = std.testing.allocator;
    
    var registry = ExchangeRegistry.init(allocator);
    defer registry.deinit();
    
    const auth_config = auth.AuthConfig{};
    
    // Test Binance
    const binance_ex = try binance.BinanceExchange.create(allocator, auth_config);
    try registry.registerExchange("binance", .binance, @ptrCast(binance_ex));
    
    try std.testing.expect(registry.hasExchange("binance"));
    try std.testing.expect(!registry.hasExchange("nonexistent"));
    
    const retrieved = registry.getExchange("binance", binance.BinanceExchange);
    try std.testing.expect(retrieved != null);
}
