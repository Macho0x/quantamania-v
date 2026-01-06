# CCXT Zig - Phase 2: Major Exchanges Implementation

A high-performance cryptocurrency trading library for Zig, implementing the 7 major crypto exchanges.

## Exchanges

### Implemented (Phase 2)

| Exchange | Status | Public API | Private API | Markets | Ticker | Order Book | OHLCV | Trades | Balance | Orders |
|----------|--------|------------|-------------|---------|--------|------------|-------|--------|---------|--------|
| **Binance** | ✅ Full | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Kraken** | ✅ Basic | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Coinbase** | ✅ Basic | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Bybit** | ⚠️ Stub | ⚠️ | ❌ | ⚠️ | ⚠️ | ⚠️ | ❌ | ❌ | ❌ | ❌ |
| **OKX** | ⚠️ Stub | ⚠️ | ❌ | ⚠️ | ⚠️ | ⚠️ | ❌ | ❌ | ❌ | ❌ |
| **Gate.io** | ⚠️ Stub | ⚠️ | ❌ | ⚠️ | ⚠️ | ⚠️ | ❌ | ❌ | ❌ | ❌ |
| **Huobi** | ⚠️ Stub | ⚠️ | ❌ | ⚠️ | ⚠️ | ⚠️ | ❌ | ❌ | ❌ | ❌ |

**Legend:**
- ✅ Fully implemented and tested
- ⚠️ Partial/stub implementation
- ❌ Not yet implemented

## Features

### Phase 1 Foundation (Completed)
- ✅ Base exchange structure
- ✅ HTTP client with connection pooling
- ✅ Authentication (HMAC-SHA256, HMAC-SHA512)
- ✅ Rate limiting
- ✅ Error handling and retry logic
- ✅ Unified data models (Market, Ticker, Order, Trade, OHLCV, Balance)
- ✅ Type-safe decimal handling
- ✅ Comprehensive utilities (crypto, JSON, URL, time)

### Phase 2 Deliverables
- ✅ Binance exchange (full implementation)
- ✅ Kraken exchange (public methods)
- ✅ Coinbase exchange (public methods)
- ✅ Bybit exchange (structure only)
- ✅ OKX exchange (structure only)
- ✅ Gate.io exchange (structure only)
- ✅ Huobi exchange (structure only)
- ✅ Exchange registry for programmatic access
- ✅ Example programs

## Quick Start

### Building

```bash
cd ccxt-zig
zig build
```

### Running Examples

```bash
# Run the main demo
zig build run

# Run examples
zig build run -- examples/basic_usage.zig
```

### Running Tests

```bash
zig build test
```

## Usage

### Basic Example

```zig
const std = @import("std");
const ccxt = @import("ccxt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create exchange with empty auth for public endpoints
    const auth_config = ccxt.auth.AuthConfig{};
    const exchange = try ccxt.binance.BinanceExchange.create(allocator, auth_config);
    defer exchange.destroy();
    
    // Fetch ticker
    const ticker = try exchange.fetchTicker("BTC/USDT");
    defer {
        var mut_ticker = ticker;
        mut_ticker.deinit(allocator);
    }
    
    std.debug.print("BTC/USDT Last: {?d:.2}\n", .{ticker.last});
}
```

### Authenticated Endpoints

```zig
const auth_config = ccxt.auth.AuthConfig{
    .apiKey = "your-api-key",
    .apiSecret = "your-api-secret",
};

const exchange = try ccxt.binance.BinanceExchange.create(allocator, auth_config);
defer exchange.destroy();

// Fetch balance
var balances = try exchange.fetchBalance();
defer {
    var it = balances.iterator();
    while (it.next()) |entry| {
        var balance = entry.value_ptr.*;
        balance.deinit(allocator);
        allocator.free(entry.key_ptr.*);
    }
    balances.deinit();
}

// Create order
const order = try exchange.createOrder(
    "BTC/USDT",
    "limit",
    "buy",
    0.001,
    50000.0,
);
defer {
    var mut_order = order;
    mut_order.deinit(allocator);
}
```

### Using Exchange Registry

```zig
var registry = ccxt.ExchangeRegistry.init(allocator);
defer registry.deinit();

// Register exchanges
const exchanges = [_]ccxt.ExchangeType{ .binance, .kraken, .coinbase };
for (exchanges) |exchange_type| {
    const name = exchange_type.toString();
    const exchange_ptr = try ccxt.createExchange(allocator, exchange_type, auth_config);
    try registry.registerExchange(name, exchange_type, exchange_ptr);
}

// Get exchange by name
if (registry.getExchange("binance", ccxt.binance.BinanceExchange)) |binance_ex| {
    const ticker = try binance_ex.fetchTicker("BTC/USDT");
    // ...
}
```

## API Reference

### Common Methods

All exchanges implement these methods:

#### Public Methods (No authentication required)

- `fetchMarkets() -> ![]Market` - Fetch all available markets
- `fetchTicker(symbol: []const u8) -> !Ticker` - Fetch 24h ticker data
- `fetchOrderBook(symbol: []const u8, limit: ?u32) -> !OrderBook` - Fetch order book
- `fetchOHLCV(symbol: []const u8, timeframe: TimeFrame, since: ?i64, limit: ?u32) -> ![]OHLCV` - Fetch candlestick data
- `fetchTrades(symbol: []const u8, since: ?i64, limit: ?u32) -> ![]Trade` - Fetch recent trades

#### Private Methods (Authentication required)

- `fetchBalance() -> !std.StringHashMap(Balance)` - Fetch account balance
- `createOrder(symbol: []const u8, type: []const u8, side: []const u8, amount: f64, price: ?f64) -> !Order` - Create an order
- `cancelOrder(orderId: []const u8, symbol: ?[]const u8) -> !Order` - Cancel an order
- `fetchOrder(orderId: []const u8, symbol: ?[]const u8) -> !Order` - Fetch order details
- `fetchOpenOrders(symbol: ?[]const u8) -> ![]Order` - Fetch open orders
- `fetchClosedOrders(symbol: ?[]const u8, since: ?i64, limit: ?u32) -> ![]Order` - Fetch closed orders

### Exchange-Specific Details

#### Binance
- **Rate Limit:** 50ms between requests (1200/min)
- **Authentication:** HMAC-SHA256 with X-MBX-APIKEY header
- **Testnet:** Supported
- **Features:** Full implementation with all public and private methods

#### Kraken
- **Rate Limit:** 1500ms between requests (tier 2)
- **Authentication:** HMAC-SHA256 with API-Key header
- **Special:** XBT currency code (normalized to BTC)
- **Features:** Public methods fully implemented

#### Coinbase
- **Rate Limit:** 67ms between requests (15/sec)
- **Authentication:** HMAC-SHA256 with CB-ACCESS-* headers
- **Features:** Public methods fully implemented

## Architecture

```
ccxt-zig/
├── src/
│   ├── base/
│   │   ├── auth.zig          # Authentication handlers
│   │   ├── errors.zig        # Error types and retry logic
│   │   ├── exchange.zig      # Base exchange structure
│   │   ├── http.zig          # HTTP client with pooling
│   │   └── types.zig         # Common types (Decimal, TimeFrame, etc.)
│   ├── models/
│   │   ├── balance.zig       # Balance model
│   │   ├── market.zig        # Market model
│   │   ├── ohlcv.zig         # OHLCV (candlestick) model
│   │   ├── order.zig         # Order model
│   │   ├── ticker.zig        # Ticker model
│   │   └── trade.zig         # Trade model
│   ├── exchanges/
│   │   ├── binance.zig       # Binance implementation
│   │   ├── kraken.zig        # Kraken implementation
│   │   ├── coinbase.zig      # Coinbase implementation
│   │   ├── bybit.zig         # Bybit stub
│   │   ├── okx.zig           # OKX stub
│   │   ├── gate.zig          # Gate.io stub
│   │   └── huobi.zig         # Huobi stub
│   ├── utils/
│   │   ├── crypto.zig        # Cryptographic utilities
│   │   ├── json.zig          # JSON parsing helpers
│   │   ├── time.zig          # Time utilities
│   │   └── url.zig           # URL encoding/parsing
│   └── main.zig              # Main entry point & registry
├── examples/
│   └── basic_usage.zig       # Usage examples
└── build.zig
```

## Performance

- Zero-copy string handling where possible
- Connection pooling for HTTP requests
- Efficient rate limiting with minimal overhead
- Arena allocators for request/response lifecycles
- Decimal precision maintained using i128 fixed-point arithmetic

## Roadmap

### Phase 3: Mid-Tier Exchanges (Next)
- 30+ additional exchanges (Bitfinex, KuCoin, BitMEX, etc.)
- Complete implementations for Phase 2 stub exchanges

### Phase 4: Advanced Features
- Margin trading support
- Futures/derivatives support
- Funding rates
- Position management
- Advanced order types

### Phase 5: WebSocket Support
- Real-time order book updates
- Ticker streams
- Trade streams
- User data streams

### Phase 6: Testing & Optimization
- Comprehensive test suite
- Performance benchmarks
- Memory profiling
- Documentation improvements

## Contributing

This is Phase 2 of the CCXT Zig implementation. Contributions are welcome!

Priority areas:
1. Complete Bybit, OKX, Gate.io, and Huobi implementations
2. Add private endpoint support for Kraken and Coinbase
3. Improve error handling and edge cases
4. Add more examples and documentation
5. Performance optimizations

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Inspired by [CCXT](https://github.com/ccxt/ccxt) (JavaScript/Python/PHP)
- Built with [Zig](https://ziglang.org/) for maximum performance and safety

## Support

For issues, questions, or contributions, please open an issue on GitHub.

---

**Note:** This is Phase 2 of the implementation. Some exchanges have partial implementations.
Always test with small amounts first when using private endpoints.
