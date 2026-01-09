const std = @import("std");
const exchange = @import("../base/exchange.zig");
const auth = @import("../base/auth.zig");
const http = @import("../base/http.zig");

// Exchange type enum for registry
pub const ExchangeType = enum {
    binance,
    kraken,
    coinbase,
    bybit,
    okx,
    gate,
    huobi,
    hyperliquid,
};

// Exchange creation function type
pub const ExchangeCreator = fn (allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque;

// Exchange metadata
pub const ExchangeInfo = struct {
    name: []const u8,
    description: []const u8,
    doc_url: []const u8,
    version: []const u8,
    requires_api_key: bool,
    requires_secret: bool,
    requires_passphrase: bool,
    testnet_supported: bool,
    spot_supported: bool,
    margin_supported: bool,
    futures_supported: bool,
};

// Exchange registry for all supported exchanges
pub const ExchangeRegistry = struct {
    allocator: std.mem.Allocator,
    exchanges: std.StringHashMap(ExchangeEntry),

    const ExchangeEntry = struct {
        info: ExchangeInfo,
        creator: ExchangeCreator,
        testnet_creator: ?ExchangeCreator,
    },

    pub fn init(allocator: std.mem.Allocator) ExchangeRegistry {
        return .{
            .allocator = allocator,
            .exchanges = std.StringHashMap(ExchangeEntry).init(allocator),
        };
    }

    pub fn deinit(self: *ExchangeRegistry) void {
        var iter = self.exchanges.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.exchanges.deinit();
    }

    pub fn register(self: *ExchangeRegistry, name: []const u8, entry: ExchangeEntry) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        try self.exchanges.put(name_copy, entry);
    }

    pub fn get(self: *ExchangeRegistry, name: []const u8) ?*const ExchangeEntry {
        return self.exchanges.get(name);
    }

    pub fn getNames(self: *ExchangeRegistry) [][]const u8 {
        var names = std.ArrayList([]const u8).init(self.allocator);
        defer names.deinit();

        var iter = self.exchanges.iterator();
        while (iter.next()) |entry| {
            names.append(entry.key_ptr.*) catch {};
        }

        return names.toOwnedSlice() catch &.{};
    }
};

// Default exchange configurations
pub const ExchangeDefaults = struct {
    pub fn getDefaultConfig() auth.AuthConfig {
        return .{
            .apiKey = null,
            .apiSecret = null,
            .passphrase = null,
            .uid = null,
            .password = null,
        };
    }
};

// Create registry with all exchanges
pub fn createDefaultRegistry(allocator: std.mem.Allocator) !ExchangeRegistry {
    var registry = ExchangeRegistry.init(allocator);

    // Register all exchanges
    try registry.register("binance", .{
        .info = .{
            .name = "Binance",
            .description = "World's largest cryptocurrency exchange with spot, margin, and futures trading",
            .doc_url = "https://binance-docs.github.io/apidocs/spot/en/",
            .version = "v3",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = true,
            .futures_supported = true,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const binance = @import("binance.zig");
                return try binance.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const binance = @import("binance.zig");
                return try binance.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    try registry.register("kraken", .{
        .info = .{
            .name = "Kraken",
            .description = "Major European cryptocurrency exchange with advanced trading features",
            .doc_url = "https://docs.kraken.com/rest/",
            .version = "v0",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = true,
            .futures_supported = true,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const kraken = @import("kraken.zig");
                return try kraken.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = null,
    });

    try registry.register("coinbase", .{
        .info = .{
            .name = "Coinbase",
            .description = "US-based exchange with beginner-friendly interface and advanced trading",
            .doc_url = "https://docs.cloud.coinbase.com/",
            .version = "v2",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = true,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const coinbase = @import("coinbase.zig");
                return try coinbase.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const coinbase = @import("coinbase.zig");
                return try coinbase.createSandbox(allocator, auth_config);
            }
        }.f,
    });

    try registry.register("bybit", .{
        .info = .{
            .name = "Bybit",
            .description = "Derivatives exchange specializing in perpetual and futures contracts",
            .doc_url = "https://bybit-exchange.github.io/docs/v5/intro",
            .version = "v5",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = true,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const bybit = @import("bybit.zig");
                return try bybit.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const bybit = @import("bybit.zig");
                return try bybit.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    try registry.register("okx", .{
        .info = .{
            .name = "OKX",
            .description = "Global cryptocurrency exchange with comprehensive trading options",
            .doc_url = "https://www.okx.com/docs-v5/en/",
            .version = "v5",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = true,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = true,
            .futures_supported = true,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const okx = @import("okx.zig");
                return try okx.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const okx = @import("okx.zig");
                return try okx.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    try registry.register("gate", .{
        .info = .{
            .name = "Gate.io",
            .description = "Global crypto exchange with spot, futures, and lending services",
            .doc_url = "https://www.gate.io/docs/apiv4/en/",
            .version = "v4",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = true,
            .futures_supported = true,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const gate = @import("gate.zig");
                return try gate.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = null,
    });

    try registry.register("huobi", .{
        .info = .{
            .name = "Huobi",
            .description = "One of the largest cryptocurrency exchanges globally",
            .doc_url = "https://huobiapi.github.io/docs/spot/v3/en/",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = true,
            .futures_supported = true,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const huobi = @import("huobi.zig");
                return try huobi.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = null,
    });

    // Hyperliquid - DEX Support (Phase 3.5)
    try registry.register("hyperliquid", .{
        .info = .{
            .name = "Hyperliquid",
            .description = "Decentralized perpetuals exchange with wallet-based trading",
            .doc_url = "https://docs.hyperliquid.xyz/",
            .version = "v1",
            .requires_api_key = false,  // Uses wallet signing instead
            .requires_secret = false,  // Uses wallet signing instead
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = false,
            .margin_supported = false,
            .futures_supported = true,  // Perpetuals
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const hyperliquid = @import("hyperliquid.zig");
                return try hyperliquid.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = null,  // TODO: Add testnet support
    });

    return registry;
}
