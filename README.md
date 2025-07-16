<img src="https://github.com/Macho0x/quantamania-v/blob/main/QUANTAMANIA.png" alt="Alt text"/>

# V Language Technical Indicators Library

A comprehensive, high-performance technical analysis library for the V programming language, featuring 66 technical indicators with type-safe configuration, comprehensive testing, and excellent performance.

## Project Structure

```
vlang-math/
├── main.v                    # Usage examples for all 66 indicators
├── test_suite.v             # Comprehensive test suite (66 tests)
├── benchmark.v              # Performance benchmarks (66 benchmarks)
├── indicators/              # Core indicator implementations
│   ├── config.v            # Configuration system with validation
│   ├── structs.v           # Data structures and types
│   └── *.v                 # Individual indicator implementations (66 files)
└── docs/
    └── CONFIGURATION.md     # Complete configuration documentation
```

## Available Indicators (66 Total)

### Trend Indicators (10)
- **Simple Moving Average (SMA)** - Basic trend following indicator
- **Exponential Moving Average (EMA)** - Weighted moving average
- **Hull Moving Average (HMA)** - Fast and smooth moving average
- **Double Exponential Moving Average (DEMA)** - Reduced lag moving average
- **Triple Exponential Moving Average (TEMA)** - Triple smoothing for reduced lag
- **Adaptive Moving Average (AMA)** - Adaptive smoothing based on market efficiency
- **Arnaud Legoux Moving Average (ALMA)** - Gaussian-weighted moving average
- **Volume Weighted Moving Average (VWMA)** - Volume-weighted price average
- **Linear Regression** - Linear trend analysis
- **Wilder's Smoothing** - Smoothing algorithm for indicators

### Oscillator Indicators (11)
- **Relative Strength Index (RSI)** - Momentum oscillator (0-100)
- **Commodity Channel Index (CCI)** - Price deviation from average
- **Williams %R** - Momentum oscillator (-100 to 0)
- **Stochastic Oscillator** - Price momentum relative to range
- **Stochastic RSI** - RSI of RSI for overbought/oversold signals
- **Awesome Oscillator** - Momentum indicator using median prices
- **Ultimate Oscillator** - Multi-timeframe momentum oscillator
- **TRIX** - Triple exponential average oscillator
- **Chande Momentum Oscillator (CMO)** - Momentum oscillator
- **Fisher Transform** - Price transformation for better signals
- **Woodies CCI** - Enhanced CCI with Turbo Lag Bands

### Momentum Indicators (9)
- **Momentum** - Rate of price change
- **Rate of Change (ROC)** - Percentage price change over period
- **Price Rate of Change (PROC)** - Price momentum indicator
- **Detrended Price Oscillator (DPO)** - Price deviation from trend
- **Percentage Price Oscillator (PPO)** - Percentage difference between EMAs
- **Ease of Movement (EOM)** - Volume-weighted momentum
- **True Strength Index (TSI)** - Double-smoothed momentum oscillator
- **Force Index** - Volume-weighted price change indicator
- **Elder Ray Index** - Bull and bear power indicator

### Volatility Indicators (6)
- **Average True Range (ATR)** - Market volatility measure
- **Standard Deviation** - Price volatility measure
- **Historical Volatility** - Statistical volatility calculation
- **Chaikin Volatility** - Volume-weighted volatility
- **Ulcer Index** - Downside volatility measure
- **Choppiness Index** - Market choppiness measurement

### Multi-Parameter Trend Indicators (6)
- **Bollinger Bands** - Volatility-based support/resistance
- **Keltner Channels** - ATR-based price channels
- **Donchian Channels** - High-low price channels
- **Parabolic SAR** - Trend following stop-loss indicator
- **Ichimoku Cloud** - Multi-component trend indicator
- **Gator Oscillator** - Jaw, teeth, and lips oscillator

### Complex Indicators (7)
- **MACD** - Moving Average Convergence Divergence
- **Average Directional Index (ADX)** - Trend strength indicator
- **Know Sure Thing (KST)** - Long-term momentum oscillator
- **Coppock Curve** - Long-term momentum indicator
- **Vortex Indicator** - Trend reversal detection
- **Volume Weighted MACD** - MACD with volume weighting
- **Klinger Oscillator** - Volume-based momentum oscillator

### Volume Indicators (13)
- **Volume Weighted Average Price (VWAP)** - Volume-weighted price average
- **Enhanced VWAP** - Advanced volume-weighted average price
- **On Balance Volume (OBV)** - Cumulative volume indicator
- **Accumulation Distribution Line (ADL)** - Volume-price accumulation
- **Money Flow Index (MFI)** - Volume-weighted RSI
- **Chaikin Money Flow (CMF)** - Volume-weighted price oscillator
- **Money Flow Volume (MFV)** - Volume-weighted price flow
- **Money Flow Oscillator (MFO)** - Advanced money flow indicator
- **Volume Rate of Change** - Volume momentum indicator
- **Volume Price Trend (VPT)** - Cumulative volume-price indicator
- **Negative Volume Index (NVI)** - Volume-based trend indicator
- **Positive Volume Index (PVI)** - Volume-based trend indicator
- **Volume Profile** - Price-volume distribution analysis

### Support and Resistance Indicators (4)
- **Pivot Points** - Key support/resistance levels
- **Fibonacci Retracements** - Golden ratio retracement levels
- **Price Channels** - Dynamic support/resistance channels
- **Andrews Pitchfork** - Trend channel indicator

## Features

### ✅ **Complete Technical Analysis Suite**
- **66 Technical Indicators** covering all major categories
- **Type-Safe Configuration System** with validation
- **Comprehensive Test Suite** with 66 test cases
- **Performance Benchmarks** for all indicators
- **Real-World Examples** demonstrating usage

### ✅ **High Performance**
- **Ultra-fast execution** - Most indicators execute in microseconds
- **Optimized algorithms** using V's performance advantages
- **Memory efficient** implementations
- **Benchmark results**: 0.39μs to 65.50μs execution time range

### ✅ **Developer Experience**
- **Type safety** with compile-time parameter checking
- **Runtime validation** with clear error messages
- **Consistent API** across all indicators
- **Comprehensive documentation** with examples
- **Easy integration** into existing V projects
