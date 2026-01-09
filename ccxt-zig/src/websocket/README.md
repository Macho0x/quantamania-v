# WebSocket Support (Phase 3)

This directory contains WebSocket implementation for real-time data streaming.

## Current Structure (Phase 3.2 - In Progress)

```
src/websocket/
├── README.md          # This file
├── ws.zig             # Core WebSocket client (stub)
├── manager.zig         # Connection manager (implemented)
├── types.zig           # WebSocket-specific types (implemented)
└── exchanges/         # Per-exchange WebSocket implementations (planned)
    ├── binance_ws.zig
    ├── kraken_ws.zig
    ├── coinbase_ws.zig
    ├── bybit_ws.zig
    ├── okx_ws.zig
    ├── gate_ws.zig
    └── huobi_ws.zig
```

## Features (Partially Implemented)

### Public WebSocket Streams
- `subscribeTicker(symbol, callback)` - Real-time ticker updates
- `subscribeOrderBook(symbol, callback)` - Order book updates
- `subscribeTrades(symbol, callback)` - Trade stream
- `subscribeOHLCV(symbol, timeframe, callback)` - Candlestick updates
- `unsubscribe(channel)` - Unsubscribe from channel

### Private WebSocket Streams
- `subscribeOrders(callback)` - Order updates
- `subscribeBalance(callback)` - Balance changes
- `subscribePositions(callback)` - Position updates (futures)

### Connection Management
- Auto-reconnect with exponential backoff
- Ping/pong heartbeat mechanism
- Message queuing during reconnection
- Multiple concurrent connections per exchange
- Subscription management

## Implementation Status

### ✅ Completed
- WebSocket connection manager (`manager.zig`)
- WebSocket types and data structures (`types.zig`)
- Basic WebSocket client stub (`ws.zig`)

### 🚀 In Progress
- Core WebSocket client implementation
- Binance WebSocket integration
- Kraken WebSocket integration

### 🔴 Not Started
- Coinbase, Bybit, OKX, Gate.io, Huobi WebSocket
- Advanced reconnection logic
- Message serialization/deserialization
- Integration with exchange registry

## Implementation Timeline

**Phase 3.2 (Weeks 8-12):**
1. Week 8: Core WebSocket client and manager ✅ (Partial)
2. Week 9-10: Binance, Kraken, Coinbase WebSocket 🚀 (In Progress)
3. Week 11: Bybit, OKX WebSocket 🔴 (Not Started)
4. Week 12: Gate.io, Huobi WebSocket + testing 🔴 (Not Started)

## Dependencies

- Zig WebSocket library (to be determined)
- Thread-safe message queue
- Event callback system

## Status

**Current:** 🟡 In Progress (Basic infrastructure complete)
**Target Start:** Phase 3.2 (Week 8)
**Priority:** High

See [../../docs/ROADMAP.md](../../docs/ROADMAP.md) for full Phase 3 plan.