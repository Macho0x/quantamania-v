# Exchange-Specific Tags and Precision Modes

This document lists the unique tags (field names) used by each exchange for price, size, amount, and other market data fields, as well as their precision handling modes.

## Centralized Exchanges (CEX)

### Binance
**Precision Mode:** `decimal_places` (tick_size supported)
**Unique Tags:**
- `stepSize`: Minimum amount increment
- `tickSize`: Minimum price increment
- `minQty`: Minimum order quantity
- `maxQty`: Maximum order quantity
- `minNotional`: Minimum order cost (quote currency)
- `filters`: Array of market filters

### Kraken
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `ordermin`: Minimum order amount
- `costmin`: Minimum order cost
- `pair_decimals`: Price decimal places
- `lot_decimals`: Amount decimal places
- `lot_multiplier`: Lot size multiplier

### Coinbase
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `base_increment`: Minimum amount increment
- `quote_increment`: Minimum price increment
- `base_min_size`: Minimum order amount
- `base_max_size`: Maximum order amount
- `min_market_funds`: Minimum market order cost
- `max_market_funds`: Maximum market order cost

### Bybit
**Precision Mode:** `tick_size` (primary)
**Unique Tags:**
- `basePrecision`: Base currency precision
- `quotePrecision`: Quote currency precision
- `minOrderQty`: Minimum order quantity
- `maxOrderQty`: Maximum order quantity
- `minPrice`: Minimum price
- `maxPrice`: Maximum price
- `tickSize`: Price tick size
- `qtyStep`: Quantity step size

### OKX
**Precision Mode:** `decimal_places` (tick_size supported)
**Unique Tags:**
- `minSz`: Minimum order size
- `maxSz`: Maximum order size
- `tickSz`: Price tick size
- `lotSz`: Amount lot size
- `ctVal`: Contract value (futures)
- `ctMult`: Contract multiplier

### Gate.io
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `amount_precision`: Amount decimal places
- `price_precision`: Price decimal places
- `min_quote_amount`: Minimum order cost
- `min_base_amount`: Minimum order amount

### Huobi / HTX
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `amount-precision`: Amount decimal places
- `price-precision`: Price decimal places
- `min-order-amt`: Minimum order amount
- `max-order-amt`: Maximum order amount
- `min-order-value`: Minimum order cost
- `value-precision`: Value decimal places

### KuCoin
**Precision Mode:** `tick_size` (primary)
**Unique Tags:**
- `baseIncrement`: Minimum amount increment (tick size)
- `quoteIncrement`: Minimum price increment (tick size)
- `baseMinSize`: Minimum order amount
- `quoteMinSize`: Minimum order cost
- `baseMaxSize`: Maximum order amount
- `quoteMaxSize`: Maximum order cost
- `priceIncrement`: Price tick size
- `priceLimitRate`: Price deviation limit
- `enableTrading`: Is trading enabled

### Bitfinex
**Precision Mode:** `significant_digits`
**Unique Tags:**
- `minimum_order_size`: Minimum order amount
- `maximum_order_size`: Maximum order amount
- `margin`: Is margin trading enabled
- `price_precision`: Price significant digits

### Gemini
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `tick_size`: Price increment
- `quote_increment`: Quote currency increment
- `min_order_size`: Minimum order size
- `max_order_size`: Maximum order size

### Bitget
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `minTradeAmount`: Minimum trade amount
- `priceScale`: Price decimal places
- `quantityScale`: Amount decimal places
- `minTradeUSDT`: Minimum USDT value

### BitMEX
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `lotSize`: Lot size
- `tickSize`: Tick size
- `initMargin`: Initial margin
- `maintMargin`: Maintenance margin
- `maxOrderQty`: Maximum order quantity

### Deribit
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `tick_size`: Price tick size
- `min_trade_amount`: Minimum trade amount
- `contract_size`: Contract size
- `settlement_period`: Settlement period

### MEXC
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `pricePrecision`: Price precision
- `quantityPrecision`: Quantity precision
- `minAmount`: Minimum order amount
- `minValue`: Minimum order value

### Bitstamp
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `minimum_order`: Minimum order size
- `trading`: Trading status
- `base_decimals`: Base currency decimals
- `counter_decimals`: Counter currency decimals

### Poloniex
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `amountPrecision`: Amount precision
- `pricePrecision`: Price precision
- `minAmount`: Minimum amount
- `minTotal`: Minimum total

### Phemex
**Precision Mode:** `tick_size`
**Unique Tags:**
- `tickSize`: Price tick size
- `qtyPrecision`: Quantity precision
- `minOrderValue`: Minimum order value
- `maxOrderQty`: Maximum order quantity

### BingX, XT.COM, CoinEx, ProBit, WOO X, Bitmart, AscendEX
**Precision Mode:** `decimal_places` (varies by exchange)
**Note:** These exchanges follow similar patterns to major exchanges but with exchange-specific field names. See individual exchange implementation files for specific tags.

## Decentralized Exchanges (DEX)

### Hyperliquid
**Precision Mode:** `decimal_places`
**Unique Tags:**
- `szDecimals`: Size decimals for perpetuals
- `maxLeverage`: Maximum leverage
- `minSize`: Minimum position size
- `tickSize`: Price tick size
- `stepSize`: Size step

### Uniswap V3
**Precision Mode:** `decimal_places` (18 for ERC20)
**Unique Tags:**
- `poolAddress`: Liquidity pool address
- `token0`: First token address
- `token1`: Second token address
- `fee`: Pool fee tier (500, 3000, 10000 basis points)
- `liquidity`: Total pool liquidity
- `sqrtPriceX96`: Current sqrt price (Q64.96 format)
- `tick`: Current tick
- `token0Decimals`: Token 0 decimals (usually 18)
- `token1Decimals`: Token 1 decimals (usually 18)
- `totalValueLockedUSD`: TVL in USD

### PancakeSwap V3
**Precision Mode:** `decimal_places` (18 for BEP20)
**Unique Tags:**
- `pairAddress`: Pair contract address
- `token0Address`: Token 0 address
- `token1Address`: Token 1 address
- `reserve0`: Token 0 reserves
- `reserve1`: Token 1 reserves
- `lpToken`: LP token address
- `totalSupply`: LP token total supply
- `token0Price`: Token 0 price in token 1
- `token1Price`: Token 1 price in token 0

### dYdX V4
**Precision Mode:** `tick_size`
**Unique Tags:**
- `marketId`: Market identifier
- `stepSize`: Amount step size (tick)
- `tickSize`: Price tick size
- `minOrderSize`: Minimum order size
- `initialMarginFraction`: Initial margin requirement
- `maintenanceMarginFraction`: Maintenance margin requirement
- `basePositionSize`: Base position size
- `oraclePrice`: Oracle price
- `fundingRate`: Current funding rate

## Precision Mode Explanation

### `decimal_places`
- Specifies the number of decimal places for rounding
- Example: `8` means round to 0.00000001
- Used by: Binance, Kraken, Coinbase, Gate.io, Huobi, most CEXs

### `significant_digits`
- Specifies the number of significant digits
- Example: `5` means 12.345 or 0.00012345
- Used by: Bitfinex

### `tick_size`
- Specifies the minimum price/amount increment
- Example: `0.01` means values must be multiples of 0.01
- Used by: Bybit, KuCoin, Phemex, dYdX, OKX (as supplement)

## Precision Utilities

All exchanges use the `precision_utils.zig` module for handling precision:

```zig
const precision_utils = @import("../utils/precision.zig");

// Initialize precision config for exchange
self.precision_config = precision_utils.ExchangePrecisionConfig.binance();

// Round to decimal places
const rounded = precision_utils.PrecisionUtils.roundToDecimalPlaces(value, 8);

// Round to tick size
const rounded = precision_utils.PrecisionUtils.roundToTickSize(value, 0.01);

// Format price with precision
const formatted = try precision_utils.formatPrice(allocator, price, 8, .decimal_places);

// Validate amount/price against market limits
try precision_utils.validateAmount(amount, min, max, precision, .decimal_places);
```

## Exchange-Specific Precision Configurations

Each exchange has a predefined precision configuration accessible via:

```zig
ExchangePrecisionConfig.binance()    // Binance config
ExchangePrecisionConfig.kraken()     // Kraken config
ExchangePrecisionConfig.kucoin()     // KuCoin config
ExchangePrecisionConfig.bitfinex()   // Bitfinex config
ExchangePrecisionConfig.dex()        // Generic DEX config (18 decimals)
```

## Common Patterns

### CEX Pattern (REST API)
1. Fetch market data from `/markets` or `/symbols` endpoint
2. Parse exchange-specific tags (minQty, tickSize, etc.)
3. Calculate precision from increment values or use explicit precision fields
4. Store in standard `MarketPrecision` struct with `amount`, `price`, `base`, `quote` fields

### DEX Pattern (GraphQL/On-chain)
1. Query subgraph or on-chain contract
2. Parse token decimals (typically 18 for ERC20/BEP20)
3. Handle tick sizes for concentrated liquidity (Uniswap V3, PancakeSwap V3)
4. Use 18 decimal precision by default for amounts

## Notes

- **CEXs** typically provide explicit precision values or increment values
- **DEXs** typically use 18 decimals for ERC20 tokens (Ethereum standard)
- Some exchanges use **tick size** (minimum increment) instead of decimal places
- **Bitfinex** uniquely uses **significant digits** instead of decimal places
- All precision handling is unified through the `precision_utils` module
- Market limits (min/max) are standardized in the `MarketLimits` struct

## See Also

- `src/utils/precision.zig` - Precision utilities implementation
- `src/models/market.zig` - Market and precision data structures
- `src/exchanges/*.zig` - Individual exchange implementations
