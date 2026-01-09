# CCXT-Zig - Phase 2: Major Exchanges Implementation

A high-performance cryptocurrency exchange library written in Zig, implementing 7 major exchanges representing ~80% of global trading volume.

## Phase 2 Overview

This phase implements the following exchanges:

| Exchange | Spot | Margin | Futures | Testnet | Authentication |
|----------|------|--------|---------|---------|----------------|
| [Binance](src/exchanges/binance.zig) | ✅ | ✅ | ✅ | ✅ | HMAC-SHA256 |
| [Kraken](src/exchanges/kraken.zig) | ✅ | ✅ | ✅ | ❌ | API-Sign |
| [Coinbase](src/exchanges/coinbase.zig) | ✅ | ❌ | ❌ | ✅ | CB-ACCESS-SIGN |
| [Bybit](src/exchanges/bybit.zig) | ✅ | ❌ | ✅ | ✅ | X-BAPI-SIGN |
| [OKX](src/exchanges/okx.zig) | ✅ | ✅ | ✅ | ✅ | OK-ACCESS-SIGN |
| [Gate.io](src/exchanges/gate.zig) | ✅ | ✅ | ✅ | ❌ | Authorization |
| [Huobi](src/exchanges/huobi.zig) | ✅ | ✅ | ✅ | ❌ | HMAC-SHA256 |

## Features

### Implemented Methods

#### Market Data (Public)
- `fetchMarkets()` - Get all trading pairs
- `fetchTicker(symbol)` - Get 24h ticker for a symbol
- `fetchOrderBook(symbol, limit)` - Get order book depth
- `fetchOHLCV(symbol, timeframe, since, limit)` - Get candlestick data
- `fetchTrades(symbol, since, limit)` - Get recent trades

#### Trading (Private - Requires API Keys)
- `fetchBalance()` - Get account balance
- `createOrder(symbol, type, side, amount, price, params)` - Place order
- `cancelOrder(orderId, symbol)` - Cancel order
- `fetchOrder(orderId, symbol)` - Get order details
- `fetchOpenOrders(symbol)` - Get open orders
- `fetchClosedOrders(symbol, since, limit)` - Get order history

### Key Features

- **Market Caching**: Markets are cached for 1 hour (configurable) to reduce API calls
- **Rate Limiting**: Built-in rate limiting with configurable limits per exchange
- **Symbol Normalization**: Unified symbol format (BTC/USDT) with exchange-specific handling
- **Precision Handling**: Proper decimal handling for prices and amounts
- **Error Mapping**: Exchange-specific errors mapped to unified `ExchangeError` types

## Quick Start

```zig
const std = @import("std");
const ccxt = @import("ccxt_zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Create exchange instance
    var auth_config = ccxt.auth.AuthConfig{
        .apiKey = "your_api_key",
        .apiSecret = "your_api_secret",
    };
    defer auth_config.deinit(allocator);

    const binance = try ccxt.binance.create(allocator, auth_config);
    defer binance.deinit();

    // Fetch markets (public endpoint)
    const markets = try binance.fetchMarkets();
    defer {
        for (markets) |*market| market.deinit(allocator);
        allocator.free(markets);
    }

    // Fetch ticker for BTC/USDT
    const ticker = try binance.fetchTicker("BTC/USDT");
    defer ticker.deinit(allocator);

    std.debug.print("BTC/USDT: ${d:.2}\n", .{ticker.last orelse 0});
}
```

## Using the Exchange Registry

```zig
var registry = try ccxt.registry.createDefaultRegistry(allocator);
defer registry.deinit();

// List all available exchanges
const names = registry.getNames();
for (names) |name| {
    if (registry.get(name)) |entry| {
        std.debug.print("{s}: {s}\n", .{ entry.info.name, entry.info.description });
    }
}

// Create a testnet exchange
if (registry.get("binance")) |info| {
    if (info.testnet_creator) |creator| {
        const exchange = try creator(allocator, auth_config);
        defer exchange.deinit();
    }
}
```

## Supported Timeframes

| Timeframe | Description |
|-----------|-------------|
| `1m` | 1 minute |
| `5m` | 5 minutes |
| `15m` | 15 minutes |
| `30m` | 30 minutes |
| `1h` | 1 hour |
| `4h` | 4 hours |
| `1d` | 1 day |
| `1w` | 1 week |
| `1M` | 1 month |

## Authentication Methods

### Binance (HMAC-SHA256)
```zig
var auth_config = ccxt.auth.AuthConfig{
    .apiKey = "your_binance_api_key",
    .apiSecret = "your_binance_api_secret",
};
```

### Kraken (API-Sign)
```zig
var auth_config = ccxt.auth.AuthConfig{
    .apiKey = "your_kraken_api_key",
    .apiSecret = "your_kraken_api_secret",
};
```

### Coinbase (CB-ACCESS-SIGN)
```zig
var auth_config = ccxt.auth.AuthConfig{
    .apiKey = "your_coinbase_api_key",
    .apiSecret = "your_coinbase_api_secret",
    .passphrase = "your_coinbase_passphrase",
};
```

### OKX (OK-ACCESS-SIGN)
```zig
var auth_config = ccxt.auth.AuthConfig{
    .apiKey = "your_okx_api_key",
    .apiSecret = "your_okx_api_secret",
    .passphrase = "your_okx_passphrase",
};
```

## Building and Testing

```bash
# Build the project
cd ccxt-zig
zig build

# Run examples
zig build examples

# Run benchmarks
zig build benchmark

# Run tests
zig build test
```

## Project Structure

```
ccxt-zig/
├── src/
│   ├── main.zig              # Main module exports
│   ├── base/
│   │   ├── types.zig         # Core types (Decimal, Timestamp, etc.)
│   │   ├── errors.zig        # Error types and handling
│   │   ├── auth.zig          # Authentication utilities
│   │   ├── http.zig          # HTTP client with retry logic
│   │   └── exchange.zig      # Base exchange functionality
│   ├── models/
│   │   ├── market.zig        # Market data structures
│   │   ├── ticker.zig        # Ticker data structures
│   │   ├── orderbook.zig     # Order book structures
│   │   ├── order.zig         # Order data structures
│   │   ├── balance.zig       # Balance structures
│   │   ├── trade.zig         # Trade data structures
│   │   ├── ohlcv.zig         # OHLCV candlestick data
│   │   └── position.zig      # Position data for futures
│   ├── utils/
│   │   ├── json.zig          # JSON parsing utilities
│   │   ├── time.zig          # Time/date utilities
│   │   ├── crypto.zig        # Cryptographic functions
│   │   └── url.zig           # URL parsing utilities
│   ├── exchanges/
│   │   ├── binance.zig       # Binance implementation
│   │   ├── kraken.zig        # Kraken implementation
│   │   ├── coinbase.zig      # Coinbase implementation
│   │   ├── bybit.zig         # Bybit implementation
│   │   ├── okx.zig           # OKX implementation
│   │   ├── gate.zig          # Gate.io implementation
│   │   ├── huobi.zig         # Huobi implementation
│   │   └── registry.zig      # Exchange registry
│   ├── tests.zig             # Unit tests
│   └── tests.zig
├── examples.zig              # Usage examples
├── benchmark.zig             # Performance benchmarks
├── build.zig                 # Build configuration
└── v.mod                     # Module metadata
```

## Exchange-Specific Notes

### Binance
- Uses `BTC/USDT` format
- Supports testnet at `https://testnet.binance.vision`
- Rate limit: 1200 requests/minute
- All timestamps in milliseconds

### Kraken
- Uses `XBT` instead of `BTC` internally
- No testnet available
- Rate limit: 20-40 calls/second (tier-based)
- Nonce in milliseconds

### Coinbase
- Uses sandbox environment for testing
- Passphrase required for authentication
- Rate limit: 15 requests/second
- Timestamps in ISO 8601 format

### Bybit
- Supports testnet
- Linear and inverse contracts
- Rate limit varies by endpoint (10-300/min)
- Uses `category` param for contract type

### OKX
- Multiple account types (funding, trading)
- Supports testnet
- Rate limit: 40 public/sec, 20 private/sec
- ISO 8601 timestamps

### Gate.io
- Uses `currency_pair` format
- No testnet
- Rate limit: 100 public/sec, 50 private/sec
- Supports both spot and futures

### Huobi
- Requires account ID for private endpoints
- Uses `base-quote` format
- Rate limit: 10 requests/sec (20 burst)
- Requires CN endpoint for some regions

## Error Handling

```zig
const ccxt = @import("ccxt_zig");

// Handle specific errors
const result = binance.fetchTicker("INVALID/PAIR");
if (result) |ticker| {
    // Success
    ticker.deinit(allocator);
} else |err| {
    switch (err) {
        error.SymbolNotFound => {
            std.debug.print("Symbol not found\n", .{});
        },
        error.RateLimitError => {
            std.debug.print("Rate limit exceeded\n", .{});
        },
        error.AuthenticationError => {
            std.debug.print("Authentication failed\n", .{});
        },
        else => {
            std.debug.print("Other error: {}\n", .{err});
        },
    }
}
```

## Performance

Benchmarks (Phase 2 - All exchanges):

| Operation | Avg Time |
|-----------|----------|
| Market Parsing | ~1-2 μs |
| OrderBook Parsing | ~2-3 μs |
| OHLCV Parsing | ~3-5 μs |
| HMAC-SHA256 Signature | ~1-2 μs |
| JSON Parsing | ~5-10 μs |
| Registry Lookup | <1 μs |

## Roadmap

### Phase 2 (Complete)
- ✅ Binance, Kraken, Coinbase, Bybit, OKX, Gate.io, Huobi
- ✅ All core market data methods
- ✅ Basic private methods (balance, orders)
- ✅ Exchange registry
- ✅ Unit tests and benchmarks

### Phase 3 (Next)
- 30+ mid-tier exchanges
- WebSocket support for real-time data
- Advanced order types
- Margin trading features

## License

MIT License - see `v.mod` for details.
