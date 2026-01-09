# WebSocket Support (Phase 3)

This directory will contain WebSocket implementation for real-time data streaming.

## Planned Structure (Phase 3.2)

```
src/websocket/
├── README.md          # This file
├── ws.zig             # Core WebSocket client
├── manager.zig        # Connection manager
├── types.zig          # WebSocket-specific types
└── exchanges/         # Per-exchange WebSocket implementations
    ├── binance_ws.zig
    ├── kraken_ws.zig
    ├── coinbase_ws.zig
    ├── bybit_ws.zig
    ├── okx_ws.zig
    ├── gate_ws.zig
    └── huobi_ws.zig
```

## Features (To Be Implemented)

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

## Implementation Timeline

**Phase 3.2 (Weeks 8-12):**
1. Week 8: Core WebSocket client and manager
2. Week 9-10: Binance, Kraken, Coinbase WebSocket
3. Week 11: Bybit, OKX WebSocket
4. Week 12: Gate.io, Huobi WebSocket + testing

## Dependencies

- Zig WebSocket library (to be determined)
- Thread-safe message queue
- Event callback system

## Status

**Current:** 🔴 Not Started (Placeholder)  
**Target Start:** Phase 3.2 (Week 8)  
**Priority:** High

See [../../docs/ROADMAP.md](../../docs/ROADMAP.md) for full Phase 3 plan.
