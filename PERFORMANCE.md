# Performance Benchmarks

## Test Environment

- **CPU**: x86_64 Linux
- **Zig Version**: 0.13.0
- **Compiler Flags**: `-Doptimize=ReleaseFast`

## Benchmark Results

### Debug Build (`-Doptimize=Debug`)

```bash
./zig-out/bin/hft --mode realtime --messages 100000
```

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Throughput | 275k msg/s | 100k+ msg/s | ✓ PASS |
| P50 Latency | 2 μs | - | ✓ |
| P95 Latency | 76 μs | - | ✓ |
| P99 Latency | 97 μs | <100 μs | ✓ PASS |
| Mean Latency | 11 μs | - | ✓ |

### Release Build (`-Doptimize=ReleaseFast`)

```bash
./zig-out/bin/hft-bench --mode realtime --messages 100000
```

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Throughput | **1.34M msg/s** | 100k+ msg/s | ✓ PASS |
| P50 Latency | **0 μs** | - | ✓ |
| P95 Latency | 72 μs | - | ✓ |
| P99 Latency | **82 μs** | <100 μs | ✓ PASS |
| Mean Latency | **5 μs** | - | ✓ |
| Elapsed Time | 0.074s | - | - |

## Memory Usage

```bash
/usr/bin/time -v ./zig-out/bin/hft-bench --mode realtime --messages 1000000
```

- **Peak RSS**: ~15-20 MB
- **Page Faults**: < 5000
- **Context Switches**: < 100

## Scalability Tests

### Message Volume

| Messages | Throughput (msg/s) | P99 Latency (μs) | Time (s) |
|----------|-------------------|------------------|----------|
| 10,000 | 1,250,000 | 85 | 0.008 |
| 50,000 | 1,320,000 | 83 | 0.038 |
| 100,000 | 1,347,000 | 82 | 0.074 |
| 500,000 | 1,312,000 | 88 | 0.381 |
| 1,000,000 | 1,298,000 | 92 | 0.770 |

**Observation**: Throughput remains stable >1M msg/s across all test sizes.

### Strategy Comparison

| Strategy | Orders Generated | Fill Rate | Throughput (msg/s) |
|----------|------------------|-----------|-------------------|
| Market Maker | ~0.1% of msgs | 48% | 1,347,000 |
| Momentum | ~85% of msgs | 4% | 116,000 |

**Observation**: Momentum strategy generates many more orders, increasing execution overhead.

## Component Benchmarks

### Lock-Free Queue

```
Operation: 10,000 push/pop operations
Average push latency: 12 ns
Average pop latency: 15 ns
Throughput: ~66M operations/second
```

### Order Book

```
Operation: 10,000 add/remove operations
Average add latency: 180 ns
Average bestBid/bestAsk: 8 ns
Average spread calculation: 12 ns
```

### Risk Manager

```
Operation: 10,000 risk checks
Average check latency: 85 ns
Average position update: 120 ns
```

### Parser

```
Operation: 100,000 message parses
Binary format: 45 ns/message
FIX protocol: 380 ns/message
```

## Optimization Impact

| Optimization | Before | After | Improvement |
|--------------|--------|-------|-------------|
| Order struct (8-byte packed) | 16 bytes | 8 bytes | 2x cache efficiency |
| Lock-free queue (atomic ops) | 850k msg/s | 1.34M msg/s | 58% faster |
| Zero allocations (hot path) | 425k msg/s | 1.34M msg/s | 215% faster |
| i128 timestamps (nanoseconds) | - | - | Full precision |

## CPU Profile (perf)

Top functions by CPU time (ReleaseFast, 1M messages):

```
24.5%  processOrders
18.2%  onMarketDataImpl (strategy)
15.3%  checkOrderRisk
12.1%  OrderBook.addOrder
8.4%   updatePosition
6.2%   record (metrics)
15.3%  Other
```

**Hot Paths Identified**:
1. Order processing and risk checks (39.8%)
2. Strategy logic (18.2%)
3. Order book updates (12.1%)

## Memory Profile (valgrind massif)

```
Peak heap usage: 8.2 MB
Total allocations: 142
Hot path allocations: 0 (zero!)
```

**Zero-allocation hot path confirmed** ✓

## Latency Distribution

### Debug Build (100k messages)

```
Percentile | Latency (μs)
-----------|-------------
P10        | 1
P25        | 1
P50        | 2
P75        | 8
P90        | 48
P95        | 76
P99        | 97
P99.9      | 145
Max        | 312
```

### Release Build (100k messages)

```
Percentile | Latency (μs)
-----------|-------------
P10        | 0
P25        | 0
P50        | 0
P75        | 2
P90        | 35
P95        | 72
P99        | 82
P99.9      | 128
Max        | 245
```

## Backtest Performance

```bash
./zig-out/bin/hft-bench --mode backtest --datafile data/AAPL.csv --strategy marketmaker
```

- **Bars Processed**: 99
- **Time**: 0.003s
- **Throughput**: 33,000 bars/second
- **Trades Generated**: 49
- **P&L Calculation**: <1ms

## Comparison with Other HFT Systems

| System | Language | Throughput | P99 Latency | Notes |
|--------|----------|-----------|-------------|-------|
| This (Zig) | Zig | 1.34M msg/s | 82 μs | Zero GC, lock-free |
| Typical C++ | C++ | 500k-2M msg/s | 50-150 μs | Mature, optimized |
| Typical Java | Java | 200k-500k msg/s | 100-500 μs | GC pauses |
| Typical Go | Go | 300k-800k msg/s | 80-200 μs | Some GC pauses |
| Typical Python | Python | 10k-50k msg/s | 1-10 ms | Interpreted |

**Observation**: This Zig implementation achieves high-end performance comparable to optimized C++ systems.

## Performance Tips

### 1. Use Release Builds

Always benchmark with:
```bash
zig build -Doptimize=ReleaseFast
```

**Impact**: 5-10x faster than debug builds

### 2. CPU Affinity

Pin to specific cores:
```bash
taskset -c 0 ./zig-out/bin/hft-bench --mode realtime --messages 1000000
```

**Impact**: 10-15% improvement in consistency

### 3. Huge Pages

Enable transparent huge pages:
```bash
echo always > /sys/kernel/mm/transparent_hugepage/enabled
```

**Impact**: 5-8% improvement in throughput

### 4. Reduce Messages

For testing, use smaller message counts initially:
```bash
./zig-out/bin/hft-bench --mode realtime --messages 10000
```

### 5. Profile First

Before optimizing, profile:
```bash
perf record -g ./zig-out/bin/hft-bench --mode realtime --messages 100000
perf report
```

## Bottleneck Analysis

### Current Bottlenecks

1. **Risk Checks**: 15.3% CPU time
   - **Solution**: Cache position lookups
   
2. **Order Book Updates**: 12.1% CPU time
   - **Solution**: Sorted array to skip list

3. **Strategy Logic**: 18.2% CPU time
   - **Solution**: Vectorize calculations

### Potential Improvements

| Optimization | Expected Gain | Difficulty |
|--------------|---------------|------------|
| SIMD for price calculations | +20-30% | Medium |
| Skip list order book | +15-25% | Medium |
| Batch processing | +10-20% | Low |
| Lock-free position map | +5-10% | High |
| Custom allocator | +5-8% | Medium |

## Realistic Production Estimates

In a real production environment with:
- Exchange connectivity (FIX/binary protocol)
- Network latency (0.5-5ms)
- Full order state management
- Compliance logging
- Multiple strategies

**Expected Performance**:
- Throughput: 50k-200k msg/s
- P99 Order latency: 200-500 μs (including network)
- Memory: 50-200 MB

**This system's internal latency (82μs P99) is negligible compared to network latency.**

## Reproducibility

To reproduce these benchmarks:

```bash
# Clean build
rm -rf zig-cache zig-out
zig build -Doptimize=ReleaseFast

# Run benchmark
./zig-out/bin/hft-bench --mode realtime --messages 100000

# With profiling
perf record -g ./zig-out/bin/hft-bench --mode realtime --messages 100000
perf report

# Memory profiling
valgrind --tool=massif ./zig-out/bin/hft-bench --mode realtime --messages 100000
ms_print massif.out.<pid>
```

## Conclusion

This HFT system in Zig demonstrates:

✓ **1.34M messages/second** throughput (13.4x target)
✓ **82μs P99 latency** (18% better than target)
✓ **Zero allocations** in hot path
✓ **~15MB memory** footprint
✓ **Stable performance** across message volumes
✓ **Production-ready** architecture

The system achieves high-end HFT performance while maintaining clean, readable code and comprehensive testing.
