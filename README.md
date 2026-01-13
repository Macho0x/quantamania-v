# CCXT-Zig - Cryptocurrency Exchange Library

A high-performance cryptocurrency exchange client written in Zig, implementing **52 exchanges** (47 CEX + 5 DEX) with unified market/order APIs, precision handling, and extensible exchange templates.

## Quick start

### Build / test / run

```bash
# Build
zig build

# Run unit tests
zig build test

# Run examples
zig build examples

# Run benchmarks
zig build benchmark
```

### Basic usage (inside this repo)

```zig
const std = @import("std");
const ccxt = @import("ccxt_zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // NOTE: AuthConfig string fields are assumed to be allocator-owned and
    // are freed by exchange.deinit().
    var auth_config = ccxt.auth.AuthConfig{
        .apiKey = try allocator.dupe(u8, "your_api_key"),
        .apiSecret = try allocator.dupe(u8, "your_api_secret"),
    };

    const binance = try ccxt.binance.create(allocator, auth_config);
    defer binance.deinit();

    const markets = try binance.fetchMarkets();
    defer {
        for (markets) |*market| market.deinit(allocator);
        allocator.free(markets);
    }

    const ticker = try binance.fetchTicker("BTC/USDT");
    defer ticker.deinit(allocator);

    std.debug.print("BTC/USDT: {d:.2}\n", .{ticker.last orelse 0});
}
```

## Supported exchanges

### Fully implemented (13)

Binance, Kraken, Coinbase, Bybit, OKX, Gate.io, Huobi, KuCoin, Hyperliquid, HTX, HitBTC, BitSO, Mercado Bitcoin, Upbit

### Complete templates (35)

Bitfinex, Gemini, Bitget, BitMEX, Deribit, MEXC, Bitstamp, Poloniex, Bitrue, Phemex, BingX, XT.COM, CoinEx, ProBit, WOO X, Bitmart, AscendEX, plus additional regional exchanges.

## Project structure

```text
.
├── build.zig
├── build.zig.zon
├── src/
│   ├── main.zig              # main module exports
│   ├── app.zig               # minimal CLI entrypoint
│   ├── base/                 # core types/errors/auth/http/exchange
│   ├── models/               # market/ticker/order/... structs
│   ├── utils/                # json/time/crypto/precision/url helpers
│   ├── websocket/            # websocket support (optional)
│   └── exchanges/            # exchange implementations + registry
├── examples.zig              # usage examples
├── benchmark.zig             # performance benchmarks
└── scripts/                  # helper scripts (python/shell)
```

## Helper scripts

- `scripts/exchange_analysis.py` / `scripts/complete_exchange_analysis.py`: fetch and compare exchange lists against upstream CCXT
- `scripts/create_exchanges.sh`: generate exchange template files under `src/exchanges/`

## License

MIT License - see LICENSE file for details.
