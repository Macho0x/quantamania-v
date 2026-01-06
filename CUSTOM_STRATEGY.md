# Creating Custom Trading Strategies

This guide shows how to implement your own trading strategies in the HFT system.

## Strategy Interface

All strategies implement the `Strategy` interface defined in `src/strategy.zig`:

```zig
pub const Strategy = struct {
    vtable: *const VTable,
    ptr: *anyopaque,

    pub const VTable = struct {
        onMarketData: *const fn (ptr: *anyopaque, msg: MarketDataMessage, 
                                book: *OrderBook, order_id_counter: *u16) ?Order,
        onOrderFill: *const fn (ptr: *anyopaque, order_id: u16, quantity: u16, price: u16) void,
        onOrderRejection: *const fn (ptr: *anyopaque, order_id: u16, reason: []const u8) void,
        getName: *const fn (ptr: *anyopaque) []const u8,
    };
};
```

## Example 1: Simple Mean Reversion Strategy

```zig
/// Mean reversion strategy
pub const MeanReversionStrategy = struct {
    window_size: usize,
    threshold: f64,
    order_size: u16,
    price_history: [200]u32,
    history_index: usize,
    history_count: usize,
    orders_sent: u64,

    pub fn init(window_size: usize, threshold: f64, order_size: u16) MeanReversionStrategy {
        return MeanReversionStrategy{
            .window_size = window_size,
            .threshold = threshold,
            .order_size = order_size,
            .price_history = [_]u32{0} ** 200,
            .history_index = 0,
            .history_count = 0,
            .orders_sent = 0,
        };
    }

    pub fn strategy(self: *MeanReversionStrategy) Strategy {
        return Strategy{
            .ptr = self,
            .vtable = &.{
                .onMarketData = onMarketDataImpl,
                .onOrderFill = onOrderFillImpl,
                .onOrderRejection = onOrderRejectionImpl,
                .getName = getNameImpl,
            },
        };
    }

    fn onMarketDataImpl(ptr: *anyopaque, msg: MarketDataMessage, 
                       book: *OrderBook, order_id_counter: *u16) ?Order {
        const self: *MeanReversionStrategy = @ptrCast(@alignCast(ptr));
        _ = book;

        // Update price history
        self.price_history[self.history_index] = msg.price;
        self.history_index = (self.history_index + 1) % 200;
        if (self.history_count < 200) {
            self.history_count += 1;
        }

        // Need enough history
        if (self.history_count < self.window_size) {
            return null;
        }

        // Calculate mean
        var sum: u64 = 0;
        var i: usize = 0;
        while (i < self.window_size) : (i += 1) {
            const idx = if (self.history_index >= i + 1)
                self.history_index - i - 1
            else
                200 + self.history_index - i - 1;
            sum += self.price_history[idx];
        }
        const mean = sum / self.window_size;

        // Check deviation
        const current_price = msg.price;
        const deviation = if (current_price > mean)
            @as(f64, @floatFromInt(current_price - mean))
        else
            @as(f64, @floatFromInt(mean - current_price));

        const deviation_pct = (deviation / @as(f64, @floatFromInt(mean))) * 100.0;

        // Generate signal if deviation exceeds threshold
        if (deviation_pct > self.threshold) {
            self.orders_sent += 1;
            order_id_counter.* +%= 1;

            // Buy if below mean, sell if above
            const side: OrderSide = if (current_price < mean) .buy else .sell;
            
            return Order.init(
                order_id_counter.*,
                @intCast(current_price),
                self.order_size,
                side,
                .limit,
            );
        }

        return null;
    }

    fn onOrderFillImpl(ptr: *anyopaque, order_id: u16, quantity: u16, price: u16) void {
        _ = ptr;
        _ = order_id;
        _ = quantity;
        _ = price;
    }

    fn onOrderRejectionImpl(ptr: *anyopaque, order_id: u16, reason: []const u8) void {
        _ = ptr;
        _ = order_id;
        _ = reason;
    }

    fn getNameImpl(ptr: *anyopaque) []const u8 {
        _ = ptr;
        return "MeanReversion";
    }
};
```

## Example 2: Volume-Weighted Strategy

```zig
/// VWAP (Volume Weighted Average Price) Strategy
pub const VWAPStrategy = struct {
    lookback: usize,
    order_size: u16,
    price_volume_history: [100]struct { price: u32, volume: u32 },
    history_index: usize,
    history_count: usize,

    pub fn init(lookback: usize, order_size: u16) VWAPStrategy {
        return VWAPStrategy{
            .lookback = lookback,
            .order_size = order_size,
            .price_volume_history = undefined,
            .history_index = 0,
            .history_count = 0,
        };
    }

    pub fn strategy(self: *VWAPStrategy) Strategy {
        return Strategy{
            .ptr = self,
            .vtable = &.{
                .onMarketData = onMarketDataImpl,
                .onOrderFill = onOrderFillImpl,
                .onOrderRejection = onOrderRejectionImpl,
                .getName = getNameImpl,
            },
        };
    }

    fn onMarketDataImpl(ptr: *anyopaque, msg: MarketDataMessage, 
                       book: *OrderBook, order_id_counter: *u16) ?Order {
        const self: *VWAPStrategy = @ptrCast(@alignCast(ptr));
        _ = book;

        // Update history
        self.price_volume_history[self.history_index] = .{
            .price = msg.price,
            .volume = msg.quantity,
        };
        self.history_index = (self.history_index + 1) % 100;
        if (self.history_count < 100) {
            self.history_count += 1;
        }

        if (self.history_count < self.lookback) {
            return null;
        }

        // Calculate VWAP
        var total_pv: u64 = 0;
        var total_volume: u64 = 0;

        var i: usize = 0;
        while (i < self.lookback) : (i += 1) {
            const idx = if (self.history_index >= i + 1)
                self.history_index - i - 1
            else
                100 + self.history_index - i - 1;

            const pv_data = self.price_volume_history[idx];
            total_pv += @as(u64, pv_data.price) * @as(u64, pv_data.volume);
            total_volume += pv_data.volume;
        }

        if (total_volume == 0) return null;

        const vwap: u32 = @intCast(total_pv / total_volume);
        const current_price = msg.price;

        // Trade when price deviates from VWAP
        const price_diff: i64 = @as(i64, @intCast(current_price)) - @as(i64, @intCast(vwap));
        const diff_pct = @abs(@as(f64, @floatFromInt(price_diff)) / @as(f64, @floatFromInt(vwap))) * 100.0;

        if (diff_pct > 0.5) {
            order_id_counter.* +%= 1;
            const side: OrderSide = if (current_price < vwap) .buy else .sell;

            return Order.init(
                order_id_counter.*,
                @intCast(current_price),
                self.order_size,
                side,
                .limit,
            );
        }

        return null;
    }

    fn onOrderFillImpl(ptr: *anyopaque, order_id: u16, quantity: u16, price: u16) void {
        _ = ptr;
        _ = order_id;
        _ = quantity;
        _ = price;
    }

    fn onOrderRejectionImpl(ptr: *anyopaque, order_id: u16, reason: []const u8) void {
        _ = ptr;
        _ = order_id;
        _ = reason;
    }

    fn getNameImpl(ptr: *anyopaque) []const u8 {
        _ = ptr;
        return "VWAP";
    }
};
```

## Example 3: Bollinger Bands Strategy

```zig
/// Bollinger Bands strategy
pub const BollingerBandsStrategy = struct {
    period: usize,
    std_dev_multiplier: f64,
    order_size: u16,
    price_history: [100]u32,
    history_index: usize,
    history_count: usize,

    pub fn init(period: usize, std_dev_multiplier: f64, order_size: u16) BollingerBandsStrategy {
        return BollingerBandsStrategy{
            .period = period,
            .std_dev_multiplier = std_dev_multiplier,
            .order_size = order_size,
            .price_history = [_]u32{0} ** 100,
            .history_index = 0,
            .history_count = 0,
        };
    }

    pub fn strategy(self: *BollingerBandsStrategy) Strategy {
        return Strategy{
            .ptr = self,
            .vtable = &.{
                .onMarketData = onMarketDataImpl,
                .onOrderFill = onOrderFillImpl,
                .onOrderRejection = onOrderRejectionImpl,
                .getName = getNameImpl,
            },
        };
    }

    fn onMarketDataImpl(ptr: *anyopaque, msg: MarketDataMessage, 
                       book: *OrderBook, order_id_counter: *u16) ?Order {
        const self: *BollingerBandsStrategy = @ptrCast(@alignCast(ptr));
        _ = book;

        // Update price history
        self.price_history[self.history_index] = msg.price;
        self.history_index = (self.history_index + 1) % 100;
        if (self.history_count < 100) {
            self.history_count += 1;
        }

        if (self.history_count < self.period) {
            return null;
        }

        // Calculate mean
        var sum: u64 = 0;
        var i: usize = 0;
        while (i < self.period) : (i += 1) {
            const idx = if (self.history_index >= i + 1)
                self.history_index - i - 1
            else
                100 + self.history_index - i - 1;
            sum += self.price_history[idx];
        }
        const mean = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(self.period));

        // Calculate standard deviation
        var variance: f64 = 0.0;
        i = 0;
        while (i < self.period) : (i += 1) {
            const idx = if (self.history_index >= i + 1)
                self.history_index - i - 1
            else
                100 + self.history_index - i - 1;
            const price_f = @as(f64, @floatFromInt(self.price_history[idx]));
            const diff = price_f - mean;
            variance += diff * diff;
        }
        variance /= @as(f64, @floatFromInt(self.period));
        const std_dev = @sqrt(variance);

        // Calculate bands
        const upper_band = mean + (self.std_dev_multiplier * std_dev);
        const lower_band = mean - (self.std_dev_multiplier * std_dev);

        const current_price_f = @as(f64, @floatFromInt(msg.price));

        // Generate signals
        if (current_price_f <= lower_band) {
            // Price at lower band - buy signal
            order_id_counter.* +%= 1;
            return Order.init(
                order_id_counter.*,
                @intCast(msg.price),
                self.order_size,
                .buy,
                .limit,
            );
        } else if (current_price_f >= upper_band) {
            // Price at upper band - sell signal
            order_id_counter.* +%= 1;
            return Order.init(
                order_id_counter.*,
                @intCast(msg.price),
                self.order_size,
                .sell,
                .limit,
            );
        }

        return null;
    }

    fn onOrderFillImpl(ptr: *anyopaque, order_id: u16, quantity: u16, price: u16) void {
        _ = ptr;
        _ = order_id;
        _ = quantity;
        _ = price;
    }

    fn onOrderRejectionImpl(ptr: *anyopaque, order_id: u16, reason: []const u8) void {
        _ = ptr;
        _ = order_id;
        _ = reason;
    }

    fn getNameImpl(ptr: *anyopaque) []const u8 {
        _ = ptr;
        return "BollingerBands";
    }
};
```

## Integrating Your Strategy

### 1. Add to strategy.zig

Add your strategy implementation to `src/strategy.zig`.

### 2. Update main.zig

Modify the CLI to support your new strategy:

```zig
const StrategyType = enum {
    marketmaker,
    momentum,
    meanreversion,  // Add your strategy
    vwap,
    bollingerbands,
};

// In runRealtime/runBacktest:
var mm = MarketMaker.init(10, 100);
var momentum = MomentumStrategy.init(20, 25, 100);
var mean_rev = MeanReversionStrategy.init(50, 2.0, 100);  // Add initialization

const strat: Strategy = switch (config.strategy_type) {
    .marketmaker => mm.strategy(),
    .momentum => momentum.strategy(),
    .meanreversion => mean_rev.strategy(),  // Add switch case
    // ... other strategies
};
```

### 3. Test Your Strategy

```bash
zig build test

# Run in real-time mode
./zig-out/bin/hft --mode realtime --strategy meanreversion --symbol AAPL

# Backtest
./zig-out/bin/hft --mode backtest --datafile data/AAPL.csv --strategy meanreversion
```

## Best Practices

### 1. State Management

Keep strategy state minimal and cache-friendly:
```zig
// Good - fixed-size arrays
price_history: [100]u32,

// Avoid - dynamic allocations in hot path
prices: std.ArrayList(u32),  // Avoid this!
```

### 2. Fast Math

Use integer arithmetic when possible:
```zig
// Fast
const mean_cents: u32 = total_price_cents / count;

// Slower (but more precise)
const mean: f64 = @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(count));
```

### 3. Avoid Allocations

Never allocate memory in `onMarketData()`:
```zig
fn onMarketDataImpl(...) ?Order {
    // NO: Don't do this in hot path
    // var list = std.ArrayList(u32).init(allocator);
    
    // YES: Use fixed-size buffers
    var buffer: [100]u32 = undefined;
    // ...
}
```

### 4. Early Returns

Exit early when conditions aren't met:
```zig
fn onMarketDataImpl(...) ?Order {
    // Check prerequisites first
    if (self.history_count < self.lookback) {
        return null;
    }
    
    // Then do expensive calculations
    const mean = self.calculateMean();
    // ...
}
```

### 5. Profiling

Benchmark your strategy:
```bash
# Build optimized
zig build -Doptimize=ReleaseFast

# Profile
perf record ./zig-out/bin/hft --mode realtime --strategy mystrategy --messages 1000000
perf report
```

## Testing Strategies

Create unit tests in `src/tests.zig`:

```zig
test "MeanReversion strategy" {
    var mean_rev = strategy.MeanReversionStrategy.init(20, 2.0, 100);
    var strat = mean_rev.strategy();

    try std.testing.expectEqualStrings("MeanReversion", strat.getName());

    var book = structures.OrderBook.init();
    book.addOrder(10000, 100, .buy);
    book.addOrder(10100, 100, .sell);

    // Feed some data
    var i: usize = 0;
    while (i < 30) : (i += 1) {
        const symbol = parser.formatSymbol("TEST");
        const msg = data.MarketDataMessage.init(
            @intCast(i),
            symbol,
            10000 + @as(u32, @intCast(i)) * 10,
            100,
            .buy,
        );

        var order_id_counter: u16 = 0;
        const order = strat.onMarketData(msg, &book, &order_id_counter);

        // Should eventually generate orders after enough history
        if (i > 20) {
            // Test logic here
        }
    }
}
```

## Next Steps

1. **Indicators**: Add technical indicators (RSI, MACD, etc.)
2. **Multi-Symbol**: Extend to trade multiple symbols simultaneously
3. **Portfolio**: Implement portfolio-level strategies
4. **Machine Learning**: Integrate prediction models
5. **Risk Models**: Add advanced risk management (VaR, Greeks)

## Resources

- See `src/strategy.zig` for MarketMaker and Momentum examples
- Check `src/data.zig` for available data structures
- Review `src/structures.zig` for OrderBook API
- Read HFT_README.md for full system architecture
