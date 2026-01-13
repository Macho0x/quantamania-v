const std = @import("std");
const exchange = @import("../base/exchange.zig");
const auth = @import("../base/auth.zig");
const http = @import("../base/http.zig");

// Exchange type enum for registry
pub const ExchangeType = enum {
    // Phase 2: Major CEX (7)
    binance,
    kraken,
    coinbase,
    bybit,
    okx,
    gate,
    huobi,
    
    // Phase 3: Mid-Tier CEX (17)
    kucoin,
    bitfinex,
    gemini,
    bitget,
    bitmex,
    deribit,
    mexc,
    bitstamp,
    poloniex,
    bitrue,
    phemex,
    bingx,
    xtcom,
    coinex,
    probit,
    woox,
    bitmart,
    ascendex,
    
    // Additional Critical CEX (21)
    htx,
    hitbtc,
    bitso,
    mercado,
    upbit,
    binanceus,
    cryptocom,
    coinbaseinternational,
    whitebit,
    bitflyer,
    bithumb,
    lbank,
    coinspot,
    indodax,
    exmo,
    hotbit,
    wazirx,
    latoken,
    bitmexfutures,
    coinmate,
    btcturk,
    zb,
    
    // Phase 3: DEX (5)
    hyperliquid,
    uniswap,
    pancakeswap,
    dydx,
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

    // === Phase 3: Mid-Tier CEX Exchanges ===
    
    try registry.register("kucoin", .{
        .info = .{
            .name = "KuCoin",
            .description = "Global crypto exchange with spot, margin, and futures",
            .doc_url = "https://docs.kucoin.com/",
            .version = "v1",
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
                const kucoin = @import("kucoin.zig");
                return try kucoin.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const kucoin = @import("kucoin.zig");
                return try kucoin.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    // === Phase 3: DEX Exchanges ===
    
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
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const hyperliquid = @import("hyperliquid.zig");
                return try hyperliquid.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    try registry.register("uniswap", .{
        .info = .{
            .name = "Uniswap",
            .description = "Leading DEX on Ethereum with AMM model",
            .doc_url = "https://docs.uniswap.org/",
            .version = "v3",
            .requires_api_key = false,
            .requires_secret = false,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const uniswap = @import("uniswap.zig");
                return try uniswap.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const uniswap = @import("uniswap.zig");
                return try uniswap.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    try registry.register("pancakeswap", .{
        .info = .{
            .name = "PancakeSwap",
            .description = "Leading DEX on BSC with AMM model",
            .doc_url = "https://docs.pancakeswap.finance/",
            .version = "v3",
            .requires_api_key = false,
            .requires_secret = false,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const pancakeswap = @import("pancakeswap.zig");
                return try pancakeswap.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const pancakeswap = @import("pancakeswap.zig");
                return try pancakeswap.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    try registry.register("dydx", .{
        .info = .{
            .name = "dYdX",
            .description = "Decentralized perpetuals exchange",
            .doc_url = "https://docs.dydx.exchange/",
            .version = "v4",
            .requires_api_key = false,
            .requires_secret = false,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = false,
            .margin_supported = false,
            .futures_supported = true,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const dydx = @import("dydx.zig");
                return try dydx.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const dydx = @import("dydx.zig");
                return try dydx.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    // === Additional Critical CEX Exchanges ===
    
    try registry.register("htx", .{
        .info = .{
            .name = "HTX",
            .description = "Global cryptocurrency exchange (formerly Huobi)",
            .doc_url = "https://huobiapi.github.io/docs/spot/v1/en/",
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
                const htx = @import("htx.zig");
                return try htx.HTX.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const htx = @import("htx.zig");
                return try htx.HTX.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    try registry.register("hitbtc", .{
        .info = .{
            .name = "HitBTC",
            .description = "Major European cryptocurrency exchange with advanced trading",
            .doc_url = "https://api.hitbtc.com/",
            .version = "v2",
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
                const hitbtc = @import("hitbtc.zig");
                return try hitbtc.HitBTC.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const hitbtc = @import("hitbtc.zig");
                return try hitbtc.HitBTC.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    try registry.register("bitso", .{
        .info = .{
            .name = "BitSO",
            .description = "Leading Latin American cryptocurrency exchange",
            .doc_url = "https://bitso.com/",
            .version = "v3",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = true,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const bitso = @import("bitso.zig");
                return try bitso.BitSO.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const bitso = @import("bitso.zig");
                return try bitso.BitSO.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    try registry.register("mercado", .{
        .info = .{
            .name = "Mercado Bitcoin",
            .description = "Major Brazilian cryptocurrency exchange",
            .doc_url = "https://www.mercadobitcoin.com.br/api-doc/",
            .version = "v4",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const mercado = @import("mercado.zig");
                return try mercado.MercadoBitcoin.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const mercado = @import("mercado.zig");
                return try mercado.MercadoBitcoin.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    try registry.register("upbit", .{
        .info = .{
            .name = "Upbit",
            .description = "Largest cryptocurrency exchange in South Korea",
            .doc_url = "https://docs.upbit.com/",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const upbit = @import("upbit.zig");
                return try upbit.Upbit.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = null,
    });

    // === Additional Critical CEX Exchanges ===
    
    try registry.register("binanceus", .{
        .info = .{
            .name = "Binance US",
            .description = "US-compliant variant of Binance",
            .doc_url = "https://docs.binance.us/",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const binanceus = @import("binanceus.zig");
                return try binanceus.BinanceUS.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const binanceus = @import("binanceus.zig");
                return try binanceus.BinanceUS.init(allocator, auth_config, true);
            }
        }.f,
    });

    try registry.register("cryptocom", .{
        .info = .{
            .name = "Crypto.com",
            .description = "Major global cryptocurrency exchange",
            .doc_url = "https://exchange-docs.crypto.com/exchange/",
            .version = "v2",
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
                const cryptocom = @import("cryptocom.zig");
                return try cryptocom.CryptoCom.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const cryptocom = @import("cryptocom.zig");
                return try cryptocom.CryptoCom.init(allocator, auth_config, true);
            }
        }.f,
    });

    try registry.register("coinbaseinternational", .{
        .info = .{
            .name = "Coinbase International",
            .description = "International variant of Coinbase",
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
                const coinbaseinternational = @import("coinbaseinternational.zig");
                return try coinbaseinternational.CoinbaseInternational.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const coinbaseinternational = @import("coinbaseinternational.zig");
                return try coinbaseinternational.CoinbaseInternational.init(allocator, auth_config, true);
            }
        }.f,
    });

    try registry.register("whitebit", .{
        .info = .{
            .name = "WhiteBit",
            .description = "Major European cryptocurrency exchange",
            .doc_url = "https://whitebit.com/docs/api",
            .version = "v1",
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
                const whitebit = @import("whitebit.zig");
                return try whitebit.WhiteBit.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const whitebit = @import("whitebit.zig");
                return try whitebit.WhiteBit.init(allocator, auth_config, true);
            }
        }.f,
    });

    try registry.register("bitflyer", .{
        .info = .{
            .name = "Bitflyer",
            .description = "Major Japanese cryptocurrency exchange",
            .doc_url = "https://bitflyer.com/api/",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const bitflyer = @import("bitflyer.zig");
                return try bitflyer.Bitflyer.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const bitflyer = @import("bitflyer.zig");
                return try bitflyer.Bitflyer.init(allocator, auth_config, true);
            }
        }.f,
    });

    try registry.register("bithumb", .{
        .info = .{
            .name = "Bithumb",
            .description = "Major Korean cryptocurrency exchange",
            .doc_url = "https://www.bithumb.com/info/api",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const bithumb = @import("bithumb.zig");
                return try bithumb.Bithumb.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = null,
    });

    try registry.register("lbank", .{
        .info = .{
            .name = "LBank",
            .description = "Global cryptocurrency exchange",
            .doc_url = "https://www.lbkex.com/docs/",
            .version = "v2",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const lbank = @import("lbank.zig");
                return try lbank.LBank.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = null,
    });

    try registry.register("coinspot", .{
        .info = .{
            .name = "Coinspot",
            .description = "Leading Australian cryptocurrency exchange",
            .doc_url = "https://www.coinspot.com.au/api",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const coinspot = @import("coinspot.zig");
                return try coinspot.Coinspot.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = null,
    });

    try registry.register("indodax", .{
        .info = .{
            .name = "Indodax",
            .description = "Major Indonesian cryptocurrency exchange",
            .doc_url = "https://indodax.com/",
            .version = "v2",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const indodax = @import("indodax.zig");
                return try indodax.Indodax.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = null,
    });

    try registry.register("exmo", .{
        .info = .{
            .name = "EXMO",
            .description = "Major Russian cryptocurrency exchange",
            .doc_url = "https://exmo.com/en/api_doc",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const exmo = @import("exmo.zig");
                return try exmo.EXMO.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = null,
    });

    try registry.register("hotbit", .{
        .info = .{
            .name = "Hotbit",
            .description = "Multi-chain cryptocurrency exchange",
            .doc_url = "https://www.hotbit.io/help/api",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const hotbit = @import("hotbit.zig");
                return try hotbit.Hotbit.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = null,
    });

    try registry.register("wazirx", .{
        .info = .{
            .name = "WazirX",
            .description = "Major Indian cryptocurrency exchange",
            .doc_url = "https://docs.wazirx.com/",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const wazirx = @import("wazirx.zig");
                return try wazirx.WazirX.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const wazirx = @import("wazirx.zig");
                return try wazirx.WazirX.init(allocator, auth_config, true);
            }
        }.f,
    });

    try registry.register("latoken", .{
        .info = .{
            .name = "Latoken",
            .description = "Multi-chain cryptocurrency exchange",
            .doc_url = "https://docs.latoken.com/",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const latoken = @import("latoken.zig");
                return try latoken.Latoken.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const latoken = @import("latoken.zig");
                return try latoken.Latoken.init(allocator, auth_config, true);
            }
        }.f,
    });

    try registry.register("bitmexfutures", .{
        .info = .{
            .name = "BitMEX Futures",
            .description = "Pioneer in crypto derivatives trading",
            .doc_url = "https://www.bitmex.com/app/api",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = false,
            .margin_supported = false,
            .futures_supported = true,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const bitmexfutures = @import("bitmexfutures.zig");
                return try bitmexfutures.BitMEXFutures.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const bitmexfutures = @import("bitmexfutures.zig");
                return try bitmexfutures.BitMEXFutures.init(allocator, auth_config, true);
            }
        }.f,
    });

    try registry.register("coinmate", .{
        .info = .{
            .name = "Coinmate",
            .description = "European cryptocurrency exchange",
            .doc_url = "https://coinmate.io/docs",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const coinmate = @import("coinmate.zig");
                return try coinmate.Coinmate.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = null,
    });

    try registry.register("btcturk", .{
        .info = .{
            .name = "BTCTurk",
            .description = "Major Turkish cryptocurrency exchange",
            .doc_url = "https://docs.btcturk.com/",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const btcturk = @import("btcturk.zig");
                return try btcturk.BTCTurk.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = null,
    });

    try registry.register("zb", .{
        .info = .{
            .name = "ZB",
            .description = "Major Chinese cryptocurrency exchange",
            .doc_url = "https://www.zb.com/i/developerApi",
            .version = "v1",
            .requires_api_key = true,
            .requires_secret = true,
            .requires_passphrase = false,
            .testnet_supported = false,
            .spot_supported = true,
            .margin_supported = false,
            .futures_supported = false,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const zb = @import("zb.zig");
                return try zb.ZB.init(allocator, auth_config, false);
            }
        }.f,
        .testnet_creator = null,
    });

    // ==================== DEX Exchanges ====================

    try registry.register("hyperliquid", .{
        .info = .{
            .name = "Hyperliquid",
            .description = "High-performance decentralized perpetuals exchange with on-chain orderbook",
            .doc_url = "https://hyperliquid.gitbook.io/hyperliquid-docs/",
            .version = "v1",
            .requires_api_key = false,
            .requires_secret = false,
            .requires_passphrase = false,
            .testnet_supported = true,
            .spot_supported = false,
            .margin_supported = false,
            .futures_supported = true,
        },
        .creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const hyperliquid = @import("hyperliquid.zig");
                return try hyperliquid.create(allocator, auth_config);
            }
        }.f,
        .testnet_creator = struct {
            fn f(allocator: std.mem.Allocator, auth_config: auth.AuthConfig) anyerror!*const anyopaque {
                const hyperliquid = @import("hyperliquid.zig");
                return try hyperliquid.createTestnet(allocator, auth_config);
            }
        }.f,
    });

    // Note: Additional mid-tier CEX exchanges (bitfinex, gemini, bitget, etc.) 
    // are implemented but not yet registered. They can be added as needed following
    // the same pattern above. See src/exchanges/*.zig for implementations.

    return registry;
}
