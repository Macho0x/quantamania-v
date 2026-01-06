# Quick Start Guide

## Installation

1. **Install Zig 0.13.0+**:
```bash
# Download and extract Zig
curl -L https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz -o zig.tar.xz
tar -xf zig.tar.xz
sudo mv zig-linux-x86_64-0.13.0 /usr/local/zig
sudo ln -sf /usr/local/zig/zig /usr/local/bin/zig
```

2. **Build the project**:
```bash
cd /path/to/hft-project
zig build
```

3. **Run tests**:
```bash
zig build test
```

## Usage Examples

### 1. Real-time Market Maker

```bash
./zig-out/bin/hft --mode realtime --strategy marketmaker --symbol AAPL --messages 100000
```

**Output:**
```
=== High-Frequency Trading System ===
Mode: Real-time Simulation
Strategy: marketmaker
Symbol: AAPL
Max Position: 10000

Processed 10000 messages...
...

=== Performance Metrics ===
Messages: 100000
Orders:   234
Messages/sec: 275433
Orders/sec:   622

Latency (microseconds):
  P50: 2
  P95: 76
  P99: 97
  Mean: 11

=== Performance Validation ===
✓ Throughput: 274503 msg/s (target: 100k+)
✓ P99 Latency: 97μs (target: <100μs)
```

### 2. Real-time Momentum Strategy

```bash
./zig-out/bin/hft --mode realtime --strategy momentum --symbol TSLA --messages 50000
```

### 3. Backtest with Historical Data

```bash
./zig-out/bin/hft --mode backtest --datafile data/AAPL.csv --strategy marketmaker --symbol AAPL
```

**Output:**
```
=== High-Frequency Trading System ===
Mode: Backtest
Strategy: marketmaker
Symbol: AAPL
Data file: data/AAPL.csv

Loading market data...
Loaded 99 bars

Running backtest...

=== Backtest Statistics ===
Total P&L:       $2450.00
Total Trades:    49
Winning Trades:  49
Losing Trades:   0
Win Rate:        100.00%
Avg Win:         $50.00
Max Drawdown:    $0.00
Sharpe Ratio:    1.847
```

### 4. Custom Parameters

```bash
# High volume with custom position limits
./zig-out/bin/hft --mode realtime --strategy marketmaker \
  --symbol NVDA --messages 500000 --max-position 5000

# Backtest with momentum strategy
./zig-out/bin/hft --mode backtest --datafile data/AAPL.csv \
  --strategy momentum --max-position 1000
```

## Performance Benchmarks

### Release Build

```bash
zig build -Doptimize=ReleaseFast
./zig-out/bin/hft --mode realtime --messages 1000000
```

**Expected Performance:**
- **Throughput**: 150k-300k messages/second
- **P50 Latency**: 1-5 microseconds
- **P99 Latency**: 50-100 microseconds
- **Memory**: < 50 MB resident
- **CPU**: Single core, ~80% utilization

## Project Structure

```
.
├── src/
│   ├── main.zig          # Entry point with CLI
│   ├── data.zig          # Core data structures
│   ├── structures.zig    # Lock-free queue, order book
│   ├── risk.zig          # Risk management
│   ├── parser.zig        # Message parsing
│   ├── strategy.zig      # Strategy framework
│   ├── execution.zig     # Order execution
│   ├── metrics.zig       # Performance metrics
│   ├── backtest.zig      # Backtesting engine
│   └── tests.zig         # Test suite
├── data/
│   └── AAPL.csv          # Sample historical data
├── build.zig             # Build configuration
├── HFT_README.md         # Full documentation
└── QUICKSTART.md         # This file
```

## Development

### Running Tests

```bash
# All tests
zig build test

# Verbose output
zig build test --summary all
```

### Building for Different Targets

```bash
# Linux x86_64 (optimized)
zig build -Dtarget=x86_64-linux -Doptimize=ReleaseFast

# macOS ARM64
zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast

# Windows x86_64
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast
```

### Debug Mode

```bash
# Build with debug symbols
zig build -Doptimize=Debug

# Run with GDB
gdb ./zig-out/bin/hft
```

## Data Format

Create your own historical data CSV:

```csv
timestamp,open,high,low,close,volume
1640000000000,150.00,151.50,149.50,151.00,1000000
1640003600000,151.00,152.00,150.50,151.50,1100000
```

- **timestamp**: Milliseconds since epoch
- **open, high, low, close**: Prices in dollars
- **volume**: Number of shares

## Common Issues

### 1. "zig: command not found"

Install Zig or add it to your PATH:
```bash
export PATH="/usr/local/zig:$PATH"
```

### 2. Build errors about i128/i64

Make sure you're using Zig 0.13.0 or later:
```bash
zig version  # Should show 0.13.0 or higher
```

### 3. Queue overflow in tests

The lock-free queue has a capacity of 10,000 orders. Process orders in batches for high volumes.

### 4. Low throughput

- Build with `-Doptimize=ReleaseFast`
- Reduce the number of position updates
- Increase `--messages` for better averaging

## Next Steps

1. **Customize Strategies**: See `src/strategy.zig` for examples
2. **Add Indicators**: Integrate technical analysis
3. **Real Exchange**: Implement FIX protocol in `src/execution.zig`
4. **More Data**: Add tick-level market data support
5. **Distributed**: Multi-threaded processing per symbol

## Performance Tips

1. **Use Release Builds**: Always benchmark with `-Doptimize=ReleaseFast`
2. **CPU Affinity**: Pin process to specific cores for consistency
3. **Huge Pages**: Enable for reduced TLB misses
4. **Network Tuning**: For real exchange connectivity, optimize TCP stack
5. **Profiling**: Use `perf` on Linux for detailed analysis

```bash
# CPU pinning
taskset -c 0 ./zig-out/bin/hft --mode realtime --messages 1000000

# Profiling
perf record -g ./zig-out/bin/hft --mode realtime --messages 100000
perf report
```

## Contributing

See HFT_README.md for full architecture details and contribution guidelines.

## License

MIT License - See LICENSE file
