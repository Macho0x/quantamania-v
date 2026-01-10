// CCXT-Zig: Cryptocurrency Exchange Library in Zig
// Phase 3: Mid-Tier Exchanges & DEX Implementation
//
// Fully Implemented Exchanges (8 total):
// - Phase 2 CEX (7): Binance, Kraken, Coinbase, Bybit, OKX, Gate.io, Huobi
// - Phase 3 CEX (1): KuCoin (all 11 methods complete)
// - Phase 3 DEX (1): Hyperliquid (perpetuals DEX)
//
// Template Implementations (20 total):
// - Phase 3 Mid-Tier CEX (17): Bitfinex, Gemini, Bitget, BitMEX, Deribit, MEXC, 
//   Bitstamp, Poloniex, Bitrue, Phemex, BingX, XT.COM, CoinEx, ProBit, WOO X, Bitmart, AscendEX
// - Phase 3 DEX (3): Uniswap V3, PancakeSwap V3, dYdX V4
//
// See TODO_STATUS.md for detailed implementation status
//
// Usage:
//   const ccxt = @import("ccxt_zig");
//   var registry = try ccxt.ExchangeRegistry.createDefaultRegistry(allocator);
//   defer registry.deinit();
//
//   if (registry.get("kucoin")) |kucoin_info| {
//       const exchange = try kucoin_info.creator(allocator, auth_config);
//       defer exchange.deinit();
//       const markets = try exchange.fetchMarkets();
//       // ... use exchange methods
//   }

const std = @import("std");

// Version information
pub const VERSION = "0.3.0";
pub const PHASE = 3;

// Base modules
pub const types = @import("base/types.zig");
pub const errors = @import("base/errors.zig");
pub const auth = @import("base/auth.zig");
pub const http = @import("base/http.zig");
pub const exchange = @import("base/exchange.zig");

// Utility modules
pub const json = @import("utils/json.zig");
pub const time = @import("utils/time.zig");
pub const crypto = @import("utils/crypto.zig");
pub const url = @import("utils/url.zig");
pub const precision = @import("utils/precision.zig");

// Data models
pub const Market = @import("models/market.zig").Market;
pub const Ticker = @import("models/ticker.zig").Ticker;
pub const OrderBook = @import("models/orderbook.zig").OrderBook;
pub const Order = @import("models/order.zig").Order;
pub const OrderType = @import("models/order.zig").OrderType;
pub const OrderSide = @import("models/order.zig").OrderSide;
pub const OrderStatus = @import("models/order.zig").OrderStatus;
pub const Balance = @import("models/balance.zig").Balance;
pub const Trade = @import("models/trade.zig").Trade;
pub const OHLCV = @import("models/ohlcv.zig").OHLCV;
pub const Position = @import("models/position.zig").Position;

// Exchange implementations - Phase 2: Major CEX
pub const binance = @import("exchanges/binance.zig");
pub const kraken = @import("exchanges/kraken.zig");
pub const coinbase = @import("exchanges/coinbase.zig");
pub const bybit = @import("exchanges/bybit.zig");
pub const okx = @import("exchanges/okx.zig");
pub const gate = @import("exchanges/gate.zig");
pub const huobi = @import("exchanges/huobi.zig");

// Exchange implementations - Phase 3: Mid-Tier CEX
pub const kucoin = @import("exchanges/kucoin.zig");
pub const bitfinex = @import("exchanges/bitfinex.zig");
pub const gemini = @import("exchanges/gemini.zig");
pub const bitget = @import("exchanges/bitget.zig");
pub const bitmex = @import("exchanges/bitmex.zig");
pub const deribit = @import("exchanges/deribit.zig");
pub const mexc = @import("exchanges/mexc.zig");
pub const bitstamp = @import("exchanges/bitstamp.zig");
pub const poloniex = @import("exchanges/poloniex.zig");
pub const bitrue = @import("exchanges/bitrue.zig");
pub const phemex = @import("exchanges/phemex.zig");
pub const bingx = @import("exchanges/bingx.zig");
pub const xtcom = @import("exchanges/xtcom.zig");
pub const coinex = @import("exchanges/coinex.zig");
pub const probit = @import("exchanges/probit.zig");
pub const woox = @import("exchanges/woox.zig");
pub const bitmart = @import("exchanges/bitmart.zig");
pub const ascendex = @import("exchanges/ascendex.zig");

// Exchange implementations - Phase 3: DEX
pub const hyperliquid = @import("exchanges/hyperliquid.zig");
pub const uniswap = @import("exchanges/uniswap.zig");
pub const pancakeswap = @import("exchanges/pancakeswap.zig");
pub const dydx = @import("exchanges/dydx.zig");

// Exchange registry
pub const registry = @import("exchanges/registry.zig");
pub const ExchangeRegistry = registry.ExchangeRegistry;
pub const ExchangeInfo = registry.ExchangeInfo;
pub const ExchangeType = registry.ExchangeType;

pub usingnamespace exchange;
