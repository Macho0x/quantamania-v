# CCXT-Zig

A high-performance, **statically typed** cryptocurrency exchange client written in **Zig**.

CCXT-Zig brings the spirit of the original [CCXT](https://github.com/ccxt/ccxt) (unified exchange APIs across many exchanges) to a systems language: predictable performance, explicit memory management, and zero runtime dependencies beyond Zig’s standard library.

> [!IMPORTANT]
> **Milestone (Phase 4++ — “Global Exchange Coverage Mastery”)**: this repository has grown from the initial “major exchange” phase into **51+ exchange modules** spanning **CEX + DEX + regional/regulated variants**. Depth varies by exchange (see the support matrix and roadmap below), but the scaffolding and architecture are designed to scale to full CCXT parity.

---

## Table of contents

- [Why CCXT-Zig exists](#why-ccxt-zig-exists)
- [Quick start (kept + enhanced)](#quick-start-kept--enhanced)
  - [Build / test / run](#build--test--run)
  - [Basic usage (inside this repo)](#basic-usage-inside-this-repo)
  - [Using CCXT-Zig as a dependency](#using-ccxt-zig-as-a-dependency)
- [Architecture & modules](#architecture--modules)
  - [`src/base/`: transport, auth, shared exchange behavior](#srcbase-transport-auth-shared-exchange-behavior)
  - [`src/models/`: normalized data structures](#srcmodels-normalized-data-structures)
  - [`src/utils/`: JSON/time/crypto/precision + Field Mapper](#srcutils-jsontimecryptoprecision--field-mapper)
  - [`src/exchanges/`: per-exchange implementations](#srcexchanges-per-exchange-implementations)
  - [`src/websocket/`: real-time transport (scaffold)](#srcwebsocket-real-time-transport-scaffold)
- [Core concepts (the things that matter in Zig)](#core-concepts-the-things-that-matter-in-zig)
  - [Allocator + lifetime patterns](#allocator--lifetime-patterns)
  - [Error handling and retries](#error-handling-and-retries)
  - [Rate limiting and caching](#rate-limiting-and-caching)
  - [Exchange Registry: discovery + late binding](#exchange-registry-discovery--late-binding)
  - [Field Mapper: exchange-specific → normalized fields](#field-mapper-exchange-specific--normalized-fields)
- [Examples](#examples)
  - [Public data: markets, ticker, order book](#public-data-markets-ticker-order-book)
  - [Exchange Registry: listing + dynamic creation](#exchange-registry-listing--dynamic-creation)
  - [Authentication and private endpoints](#authentication-and-private-endpoints)
  - [Placing orders (advanced)](#placing-orders-advanced)
  - [Robust error handling patterns](#robust-error-handling-patterns)
  - [Field Mapper examples (OKX/Hyperliquid vs Binance)](#field-mapper-examples-okxhyperliquid-vs-binance)
  - [Hyperliquid: DEX/perps + custom field mappings](#hyperliquid-dexperps--custom-field-mappings)
  - [Caching + rate limiting examples](#caching--rate-limiting-examples)
  - [WebSocket subscriptions (scaffold)](#websocket-subscriptions-scaffold)
- [Exchange support matrix](#exchange-support-matrix)
- [Roadmap & progress](#roadmap--progress)
- [Performance benchmarks](#performance-benchmarks)
- [Troubleshooting](#troubleshooting)
- [Performance tips](#performance-tips)
- [Contributing](#contributing)
- [License](#license)

---

## Why CCXT-Zig exists

The original CCXT (JavaScript/Python/PHP) is the de-facto standard for unified cryptocurrency exchange APIs. It solves a hard problem: every exchange exposes different endpoints, different field names, different symbol formats, different authentication schemes, and different error semantics.

CCXT-Zig aims to provide similar benefits **without** giving up systems-level control:

- **Predictable performance**: Zig compiles to a single native binary.
- **Explicit memory management**: no hidden allocations; data lifetimes are visible.
- **Static typing**: your compiler is a collaborator (not an afterthought).
- **Low overhead JSON parsing + normalization**: the Field Mapper system reduces “if exchange == …” parsing logic.
- **A path to “runtime exchange selection”** while staying idiomatic Zig (via the registry + creator functions).

Use CCXT-Zig when you care about:

- low latency ingestion of market data,
- building trading systems where memory/CPU are part of the product,
- embedding exchange access inside other native systems.

Use the original CCXT JavaScript library when you primarily care about:

- maximum exchange coverage today,
- quickest prototyping across web stacks,
- dynamic runtime behavior and scripting.

---

## Quick start (kept + enhanced)

### Build / test / run

CCXT-Zig targets Zig **0.13.x**.

```bash
# Build the ccxt CLI (prints version + hints)
zig build

# Run the minimal CLI
zig build run

# Run unit tests (mostly parsing tests using mock JSON)
zig build test

# Run examples (see examples.zig)
zig build examples

# Run performance benchmarks (see benchmark.zig)
zig build benchmark

# Optional: enable websocket module import (API scaffold)
zig build -Dwebsocket=true
```

### Basic usage (inside this repo)

This example intentionally shows **allocator ownership** and `defer`-based lifetime management.

```zig
const std = @import("std");
const ccxt = @import("ccxt_zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // AuthConfig fields are *optional*; if you set them, allocate them with the
    // same allocator you pass to the exchange.
    //
    // Ownership note:
    // - Most exchanges store AuthConfig and free its string fields on deinit.
    // - That means you should not free apiKey/apiSecret/passphrase yourself
    //   after passing AuthConfig into create().
    var auth_config = ccxt.auth.AuthConfig{
        .apiKey = try allocator.dupe(u8, "your_api_key"),
        .apiSecret = try allocator.dupe(u8, "your_api_secret"),
    };

    const binance = try ccxt.binance.create(allocator, auth_config);
    defer binance.deinit();

    // Markets are cached on the exchange instance.
    // Treat the returned slice as *exchange-owned* unless the method documents
    // otherwise.
    const markets = try binance.fetchMarkets();
    std.debug.print("Fetched {d} markets\n", .{markets.len});

    const ticker = try binance.fetchTicker("BTC/USDT");
    defer ticker.deinit(allocator);

    std.debug.print("BTC/USDT last: {d:.2}\n", .{ticker.last orelse 0});
}
```

### Using CCXT-Zig as a dependency

Zig’s package/dependency story continues to evolve. Typical options:

1. **Git submodule / vendoring**: place this repository under `libs/ccxt-zig/` and add a module import in your `build.zig`.
2. **`zig fetch`** (recommended when you have a stable URL + hash):

```bash
# Example (you will need to pin a revision/hash appropriate for your project)
zig fetch --save <repo-url>
```

Then in `build.zig` add:

```zig
const ccxt_dep = b.dependency("ccxt-zig", .{});
exe.root_module.addImport("ccxt_zig", ccxt_dep.module("ccxt-zig"));
```

---

## Architecture & modules

CCXT-Zig is organized so that exchange-specific code is small and the reusable machinery is centralized.

```text
.
├── src/
│   ├── main.zig              # public module exports + milestone notes
│   ├── app.zig               # minimal CLI entrypoint
│   ├── base/                 # HTTP, auth, shared exchange behavior, errors
│   ├── models/               # Market/Ticker/OrderBook/Order/Trade/etc.
│   ├── utils/                # JSON/time/crypto/precision/url + Field Mapper
│   ├── websocket/            # websocket support (currently a scaffold)
│   └── exchanges/            # per-exchange implementations + registry
├── examples.zig              # runnable examples
└── benchmark.zig             # microbenchmarks and parsing perf
```

### `src/base/`: transport, auth, shared exchange behavior

`src/base/` is the “engine room”:

- **`http.zig`**: HTTP client with keep-alive + retry/backoff logic.
- **`auth.zig`**: credential container (`AuthConfig`) plus exchange-specific signing helpers.
- **`exchange.zig`**: `BaseExchange`, holding:
  - an allocator,
  - the HTTP client,
  - default headers,
  - a JSON parser,
  - **market cache** state,
  - basic **rate limit** counters.
- **`errors.zig`**: shared error enums and retry classification utilities.

The goal is that each exchange implementation is mostly:

1. endpoint URL construction,
2. exchange-specific authentication rules,
3. parsing + normalization into `models/`.

### `src/models/`: normalized data structures

The `models/` folder defines the “CCXT surface area” in Zig types:

- `Market` (symbol, base/quote, precision, limits, info)
- `Ticker`
- `OrderBook`
- `Order`
- `Trade`
- `Balance`
- `OHLCV`
- `Position`

Each model generally provides a `deinit(allocator)` to free its owned allocations.

> [!NOTE]
> In Zig, **the type should make ownership explicit**. If a model owns a string/slice, it should document it and provide a `deinit()`.

### `src/utils/`: JSON/time/crypto/precision + Field Mapper

Utility code keeps exchange implementations consistent:

- **JSON**: shared parser helpers.
- **Time**: timestamps, conversions.
- **Crypto**: HMAC helpers and encoding.
- **Precision**: consistent rounding/amount/price behavior.
- **Field Mapper**: centralized mapping from exchange-specific field names (like `px`, `sz`) to standard internal field names (like `price`, `size`).

Field Mapper is documented in depth in **[`docs/FIELD_MAPPER.md`](docs/FIELD_MAPPER.md)**.

### `src/exchanges/`: per-exchange implementations

Each file under `src/exchanges/` follows a common pattern:

1. an exchange struct containing:
   - `allocator`,
   - `base: BaseExchange`,
   - auth fields (API key/secret/passphrase or wallet keys),
   - sometimes a `precision_config`,
   - sometimes a `field_mapping`.
2. `create()` / `createTestnet()` constructors (where supported)
3. `deinit()`
4. `fetchMarkets()`, `fetchTicker()`, `fetchOrderBook()`, `fetchOHLCV()`, …
5. parse helpers: `parseMarket()`, `parseTicker()`, etc.

### `src/websocket/`: real-time transport (scaffold)

The websocket layer is currently a **foundation/scaffold**:

- `websocket/ws.zig`: a `WebSocketClient` API with connection state.
- `websocket/manager.zig`: a manager for multiple connections.
- `websocket/types.zig`: common subscription types.

> [!WARNING]
> The websocket client methods currently return `WebSocketError.NotImplemented` for send/recv.
> The types and orchestration are in place, but the transport implementation is intentionally staged for later roadmap milestones.

---

## Core concepts (the things that matter in Zig)

### Allocator + lifetime patterns

Zig code is fast when you are explicit about memory. CCXT-Zig follows a few patterns:

1. **You pass an allocator into `create()`**.
2. The exchange stores it and uses it for internal allocations.
3. Most objects provide `deinit()` to free what they allocated.
4. Call `defer something.deinit()` immediately after success.

> [!IMPORTANT]
> **Ownership guideline** (practical rule of thumb)
>
> - If a function returns a *model instance* (like `Ticker` or `OrderBook`), you typically call `model.deinit(allocator)`.
> - If a function returns a *slice*, read the documentation/implementation:
>   - `fetchMarkets()` is commonly **cached and exchange-owned**.
>   - Methods like `fetchOHLCV()` often return **caller-owned** slices.
>
> When unsure, inspect the exchange implementation (search for `toOwnedSlice()` and whether it stores the slice on `self.base`).

### Error handling and retries

There are two layers of error handling:

1. **Zig errors** (`!T`) returned from API calls.
2. **Retry/backoff** in the HTTP layer (`src/base/http.zig`) which retries:
   - network failures,
   - `5xx` server errors,
   - `429` rate limits (with a minimum delay).

`src/base/errors.zig` provides:

- `ExchangeError` enum (e.g. `RateLimitError`, `AuthenticationError`, …)
- `RetryConfig` for delay curves
- `RetryClassifier` to decide when a request is retryable

### Rate limiting and caching

CCXT-Zig implements two pragmatic “performance levers”:

- **Market caching** in `BaseExchange`: `markets`, `last_markets_fetch`, `markets_cache_ttl_ms`.
- **Rate limit counters** in `BaseExchange`: `rate_limit`, `request_counter`, and `rate_limit_reset`.

Many `fetchMarkets()` implementations already use the cache check (`isMarketsCacheValid()`); you can tune TTL per exchange instance.

### Exchange Registry: discovery + late binding

`src/exchanges/registry.zig` defines an `ExchangeRegistry` that registers every exchange with:

- a canonical name (e.g. `"binance"`),
- `ExchangeInfo` metadata (spot/margin/futures support, docs URL, credential requirements),
- a `creator` function pointer,
- optionally a `testnet_creator`.

This is useful for:

- listing which exchanges are compiled into your binary,
- building CLIs that let users select an exchange by name,
- progressively moving toward runtime selection.

> [!NOTE]
> The registry’s `creator` returns `*const anyopaque`. To call exchange methods you must cast to the concrete type you expect.
> A future evolution would be a vtable-based “trait” wrapper for truly dynamic dispatch.

### Field Mapper: exchange-specific → normalized fields

Different exchanges use different JSON field names for the same concept:

- **OKX / Hyperliquid**: `px` (price), `sz` (size)
- **Binance**: `price`, `qty`
- **Bybit**: `lastPrice`, `size`
- **Kraken**: single-letter fields like `c`, `b`, `a` (and `XBT` for BTC)

The **Field Mapper** centralizes this mapping so exchange code can ask for “price” and let the mapper locate the exchange’s actual field name.

See the full system design and examples in **[`docs/FIELD_MAPPER.md`](docs/FIELD_MAPPER.md)**.

---

## Examples

All examples below are written as **library usage** (not internal parsing tests). You can also look at [`examples.zig`](examples.zig) for runnable samples.

### Public data: markets, ticker, order book

```zig
const std = @import("std");
const ccxt = @import("ccxt_zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const ex = try ccxt.coinbase.create(allocator, .{});
    defer ex.deinit();

    _ = try ex.fetchMarkets(); // cached; do not free directly

    const ticker = try ex.fetchTicker("BTC/USD");
    defer ticker.deinit(allocator);

    const book = try ex.fetchOrderBook("BTC/USD", 20);
    defer book.deinit(allocator);

    std.debug.print("{s}: last={d:.2} bid={d:.2} ask={d:.2}\n", .{
        ticker.symbol,
        ticker.last orelse 0,
        ticker.bid orelse 0,
        ticker.ask orelse 0,
    });

    if (book.bids.len > 0 and book.asks.len > 0) {
        std.debug.print("Top of book: {d:.2} / {d:.2}\n", .{ book.bids[0].price, book.asks[0].price });
    }
}
```

### Exchange Registry: listing + dynamic creation

```zig
const std = @import("std");
const ccxt = @import("ccxt_zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var registry = try ccxt.registry.createDefaultRegistry(allocator);
    defer registry.deinit();

    const names = registry.getNames();
    defer allocator.free(names);

    for (names) |name| {
        const entry = registry.get(name).?;
        std.debug.print("{s:16} | spot={} margin={} futures={} | {s}\n", .{
            entry.info.name,
            entry.info.spot_supported,
            entry.info.margin_supported,
            entry.info.futures_supported,
            entry.info.doc_url,
        });
    }

    // Optional: create an exchange via the registry creator (requires a cast).
    if (registry.get("binance")) |binance_entry| {
        const opaque = try binance_entry.creator(allocator, .{});

        // Creator returns anyopaque; cast to the concrete type you expect.
        const binance: *ccxt.binance.BinanceExchange =
            @ptrCast(@alignCast(@constCast(opaque)));
        defer binance.deinit();

        const t = try binance.fetchTicker("BTC/USDT");
        defer t.deinit(allocator);

        std.debug.print("\nBinance BTC/USDT last={d:.2}\n", .{t.last orelse 0});
    }
}
```

> [!CAUTION]
> The registry enables **late binding**, but Zig still requires you to decide which concrete type you’re working with.
> For a truly dynamic “single exchange interface”, CCXT-Zig will likely grow a vtable/wrapper type in a future milestone.

### Authentication and private endpoints

Authentication is exchange-specific (some require passphrases; DEXs may require wallet signing).

```zig
const std = @import("std");
const ccxt = @import("ccxt_zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Allocate strings with the same allocator used by the exchange.
    var auth_config = ccxt.auth.AuthConfig{
        .apiKey = try allocator.dupe(u8, "YOUR_KEY"),
        .apiSecret = try allocator.dupe(u8, "YOUR_SECRET"),
        .passphrase = try allocator.dupe(u8, "YOUR_PASSPHRASE"), // needed on some exchanges
    };

    const okx = try ccxt.okx.create(allocator, auth_config);
    defer okx.deinit();

    // Example private call (availability varies per exchange/module maturity).
    // const balances = try okx.fetchBalance();
    // defer allocator.free(balances);
}
```

### Placing orders (advanced)

Order placement is where most “real exchange differences” live: parameters, precision, order types, and error semantics differ.

```zig
const std = @import("std");
const ccxt = @import("ccxt_zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var auth_config = ccxt.auth.AuthConfig{
        .apiKey = try allocator.dupe(u8, "YOUR_KEY"),
        .apiSecret = try allocator.dupe(u8, "YOUR_SECRET"),
    };

    const gate = try ccxt.gate.create(allocator, auth_config);
    defer gate.deinit();

    // Params are typically optional and exchange-specific.
    var params = std.StringHashMap([]const u8).init(allocator);
    defer params.deinit();

    // Example (commented because it requires credentials and live trading):
    // const order = try gate.createOrder(
    //     "BTC/USDT",
    //     .limit,
    //     .buy,
    //     0.001,
    //     50000.0,
    //     &params,
    // );
    // defer order.deinit(allocator);
}
```

### Robust error handling patterns

Zig encourages handling errors explicitly and locally:

```zig
const std = @import("std");
const ccxt = @import("ccxt_zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const ex = try ccxt.binance.create(allocator, .{});
    defer ex.deinit();

    const ticker = ex.fetchTicker("BTC/USDT") catch |err| {
        switch (err) {
            error.RateLimitError => {
                // In many cases the HTTP layer already retries 429s, but you may still
                // see rate-limit errors depending on the endpoint and implementation.
                std.debug.print("Rate limited; try again later\n", .{});
                return;
            },
            error.AuthenticationRequired, error.AuthenticationError => {
                std.debug.print("Auth error; check API keys\n", .{});
                return;
            },
            else => return err,
        }
    };
    defer ticker.deinit(allocator);

    std.debug.print("last={d:.2}\n", .{ticker.last orelse 0});
}
```

If you are building higher-level workflows, `src/base/errors.zig` also includes `RetryConfig` and `RetryClassifier` helpers you can reuse.

### Field Mapper examples (OKX/Hyperliquid vs Binance)

The Field Mapper lets you write parsing code against standard names like `"price"` and `"size"`, while the mapping resolves the exchange’s actual JSON keys.

```zig
const std = @import("std");
const ccxt = @import("ccxt_zig");
const field_mapper = ccxt.field_mapper;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // OKX-style mapping (px/sz)
    var okx_map = try field_mapper.FieldMapperUtils.getFieldMapping(allocator, "okx");
    defer okx_map.deinit();

    // Binance-style mapping (price/qty)
    var binance_map = try field_mapper.FieldMapperUtils.getFieldMapping(allocator, "binance");
    defer binance_map.deinit();

    var parser = ccxt.json.JsonParser.init(allocator);
    defer parser.deinit();

    const okx_json =
        \\{"px": 50000, "sz": 1.5, "ts": 1700000000000}
    ;
    const binance_json =
        \\{"price": "50000.00", "qty": "1.5", "timestamp": 1700000000000}
    ;

    const okx_parsed = try parser.parse(okx_json);
    defer okx_parsed.deinit();

    const binance_parsed = try parser.parse(binance_json);
    defer binance_parsed.deinit();

    const okx_price = field_mapper.FieldMapperUtils.getFloatField(
        &parser,
        okx_parsed.value,
        "price",
        &okx_map,
        0,
    );

    const binance_price = field_mapper.FieldMapperUtils.getFloatField(
        &parser,
        binance_parsed.value,
        "price",
        &binance_map,
        0,
    );

    std.debug.print("OKX price={d} Binance price={d}\n", .{ okx_price, binance_price });
}
```

> [!TIP]
> The Field Mapper also supports **validation** before parsing (e.g. “do we have all required fields for a trade?”).
> See `validateOperation()` in [`docs/FIELD_MAPPER.md`](docs/FIELD_MAPPER.md).

### Hyperliquid: DEX/perps + custom field mappings

Hyperliquid is a good example of why normalization matters:

- its API is POST-based (`/info`, `/exchange`) with typed bodies,
- it uses `px` and `sz` heavily,
- it returns an L2 order book with `levels` arrays.

Hyperliquid initializes a mapping once per exchange instance:

```zig
// from src/exchanges/hyperliquid.zig
self.field_mapping = try field_mapper.FieldMapperUtils.getFieldMapping(allocator, "hyperliquid");
```

Then parsing can consistently ask for standard names:

```zig
const price = field_mapper.FieldMapperUtils.getFloatField(parser, json_val, "price", mapper, 0);
const size  = field_mapper.FieldMapperUtils.getFloatField(parser, json_val, "size",  mapper, 0);
```

For the full set of Hyperliquid mappings and endpoint shapes, see the dedicated section in **[`docs/FIELD_MAPPER.md`](docs/FIELD_MAPPER.md)**.

### Caching + rate limiting examples

**Market caching** (common):

```zig
const markets_a = try ex.fetchMarkets();
const markets_b = try ex.fetchMarkets();
// markets_b usually returns the cached slice.
_ = markets_a;
_ = markets_b;
```

You can tune TTL per instance:

```zig
ex.base.markets_cache_ttl_ms = 5 * 60 * 1000; // 5 minutes
```

And you can force a refresh:

```zig
ex.base.invalidateMarketsCache();
_ = try ex.fetchMarkets();
```

**Rate limiting** currently exists as a shared mechanism in `BaseExchange`, but enforcement is exchange/endpoint-dependent.
If you build higher-level loops, prefer a backoff wrapper around calls and treat `error.RateLimitError` as retryable.

### WebSocket subscriptions (scaffold)

The websocket layer defines types and orchestration, but the transport is not fully implemented yet.

```zig
const std = @import("std");
const ccxt = @import("ccxt_zig");
const ws = ccxt.websocket;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var client = try ws.WebSocketClient.init(allocator, "wss://example.com/ws");
    defer client.deinit();

    try client.connect();
    defer client.close();

    // send/recv currently return NotImplemented
    // try client.sendText("{\"op\":\"subscribe\"}");
}
```

---

## Exchange support matrix

CCXT-Zig currently includes **51+ exchange modules** across major CEX, mid-tier CEX, regional leaders, and DEX.

### Progress snapshot

The project has evolved through phases (from `src/main.zig` milestone notes):

- **Phase 2 (Major CEX)**: Binance, Kraken, Coinbase, Bybit, OKX, Gate.io, Huobi
- **Phase 3 (Mid-tier + DEX)**: expanded with KuCoin, Hyperliquid, and many additional templates
- **Phase 4++**: global coverage across continents + platform variants

### Fully implemented exchanges (13 “flagship targets”)

The following are listed as the project’s **flagship, full implementations** (as tracked in the project roadmap and README milestones):

- Binance
- Kraken
- Coinbase
- Bybit
- OKX
- Gate.io
- Huobi / HTX (rebrand)
- KuCoin
- Hyperliquid
- HitBTC
- BitSO
- Mercado Bitcoin
- Upbit

> [!NOTE]
> Some of the “flagship target” exchanges are still being actively filled out endpoint-by-endpoint.
> In particular, many of the additional/regional exchanges compile and register cleanly but may still have `NotImplemented` methods.

### Template-based implementations (35+)

Template-based implementations provide:

- consistent struct layout,
- base URL + default headers,
- precision configuration placeholders,
- method stubs ready to be implemented.

Examples include: Bitfinex, Gemini, Bitget, BitMEX, Deribit, MEXC, Bitstamp, Poloniex, Phemex, BingX, XT.COM, CoinEx, ProBit, WOO X, Bitmart, AscendEX, plus many regional variants (BinanceUS, Coinbase International, BTCTurk, Indodax, WazirX, …).

### Exchange categories (CEX/DEX/variants)

| Category | What it means | Examples present in this repo |
|---|---|---|
| Major CEX | highest liquidity + global reach | Binance, Coinbase, Kraken, OKX |
| Derivatives-focused CEX | futures/perps depth | Bybit, Deribit (template), BitMEX (template) |
| Regional leaders | top exchanges by region | Upbit (KR), BTCTurk (TR), Indodax (ID), Mercado Bitcoin (BR) |
| Regulated/variant platforms | jurisdiction-specific endpoints | BinanceUS, Coinbase International |
| DEX / on-chain venues | wallet-based auth, chain interactions | Hyperliquid, Uniswap V3 (template), PancakeSwap V3 (template), dYdX V4 (template) |

### Regional coverage “map” (high-level)

| Region | Representative exchanges in-tree | Notes |
|---|---|---|
| North America | Coinbase, Coinbase International, BinanceUS | regulated variants matter |
| Europe | Kraken, WhiteBit (template), Bitstamp (template) | EUR pairs + regional compliance |
| East Asia | Upbit (KR), Bithumb (template), Bitflyer (template) | different symbol + market formats |
| South / SE Asia | WazirX (template), Indodax (template) | fast-growing regional liquidity |
| LatAm | BitSO (MX), Mercado Bitcoin (BR) | local fiat rails and market quirks |
| Global | Binance, OKX, Bybit, Gate.io | cross-region APIs and rate-limit policies |
| On-chain / DEX | Hyperliquid, Uniswap, PancakeSwap, dYdX | wallet signing + chain context |

---

## Roadmap & progress

### Current phase

**Phase 4++** (as described in `src/main.zig`):

- **51 exchanges implemented** (historic milestone vs original 8)
- global regional coverage across continents
- platform variants (US-compliant, international, regional leaders)
- specialized venues (derivatives, futures, multi-chain)

### Upcoming milestones

1. **Complete Field Mapper adoption**
   - migrate remaining major exchanges to the mapper for consistency
   - enforce per-operation validation (`validateOperation`) in parsing
2. **Production-grade websocket transport**
   - implement `sendText`/`recv` and heartbeat/ping-pong
   - add exchange-specific WS adapters
3. **Unified dynamic exchange interface**
   - vtable/wrapper around exchange methods so registry creation returns a callable interface
4. **Deeper order/trading parity**
   - advanced order types, reduce-only, post-only, time-in-force, etc.
5. **Better symbol normalization + market metadata**
   - improve symbol transforms (e.g. Kraken XBT)
   - more robust precision/limits handling

### Comparison with CCXT (JavaScript)

| Dimension | CCXT (JS) | CCXT-Zig |
|---|---|---|
| Runtime | dynamic (Node/browser) | native binary |
| Typing | dynamic | static (compile-time) |
| Memory | GC managed | explicit allocator-based |
| Exchange count | extremely high | 51+ modules in-tree, depth varies |
| Performance | good, but higher overhead | designed for low overhead parsing + throughput |
| Extensibility | fast prototyping | template-driven, explicit parsing/auth |

### Development status

- **Stability**: core architecture is stable; individual exchanges continue to mature.
- **Test coverage**: parsing and registry are covered by unit tests (`src/tests.zig`). Network calls are not used in unit tests.
- **Production readiness**: suitable for controlled environments; for production trading, validate per-exchange behavior and ensure safe order logic.

---

## Performance benchmarks

Benchmarks live in **[`benchmark.zig`](benchmark.zig)** and focus on:

- ticker parsing,
- order book parsing,
- OHLCV parsing,
- crypto primitives (HMAC/base64),
- JSON parsing,
- registry lookup overhead,
- decimal conversion.

Run them with:

```bash
zig build benchmark
```

Example output format (abbreviated):

```text
Test Name                      | Iterations | Avg Time     | Total Time    | Std Dev
Market Parsing                 |   1000x    |    ... us/op |    ... ms     |  ... us
OrderBook Parsing              |   1000x    |    ... us/op |    ... ms     |  ... us
...
```

---

## Troubleshooting

### “Zig version mismatch” / build errors

- Ensure you are on Zig **0.13.x**.
- If you see standard library API mismatches, upgrade/downgrade Zig accordingly.

### TLS / networking failures

- Some endpoints fail if your system clock is wrong.
- Corporate proxies can break TLS; `HttpClient` supports `setProxy()`.

### Getting `RateLimitError`

- Some exchanges use strict per-endpoint limits.
- Prefer reusing a single exchange instance and let the HTTP layer retry 429/5xx.
- Add explicit delays in your app if you are polling many symbols.

### “double free” / memory issues

- Treat `fetchMarkets()` results as **exchange-owned** unless you have explicitly copied them.
- Always call `deinit()` on models you receive (like `Ticker`, `OrderBook`, `Order`).

---

## Performance tips

- Reuse a single exchange instance rather than creating/destroying repeatedly.
- Keep market caching enabled; set TTL based on your strategy.
- Prefer `std.heap.ArenaAllocator` for short-lived bursts of parsing (and reset between bursts).
- Avoid repeated symbol allocations; pass string slices where possible.
- Enable HTTP logging only when debugging (`http_client.enableLogging(true)`), as it is costly.

---

## Contributing

Contributions are welcome, especially around:

- filling in template exchanges (public endpoints first: markets/ticker/order book),
- extending Field Mapper mappings,
- adding operation-level validation in parsing,
- websocket transport and exchange-specific WS adapters,
- improving tests (mock JSON fixtures + parser coverage).

Suggested workflow:

1. Pick an exchange from the registry that is currently a template.
2. Implement `fetchMarkets()` and `parseMarket()`.
3. Add parsing tests under `src/tests.zig` using mock JSON.
4. Keep memory ownership explicit (provide `deinit` where needed).

---

## License

**MIT License** — see [LICENSE](LICENSE).
