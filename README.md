# V Language Technical Indicators Library

1. main.v = examples of how to use the library
2. test_suite.v = test suite for the library
3. benchmark.v = benchmark for the library
4. indicators/ = indicators for the library
5. indicators/structs.v = structs for the indicators
6. indicators/config.v = config for the indicators

## Available Indicators

### Trend Indicators
- **Simple Moving Average (SMA)** - Basic trend following indicator
- **Exponential Moving Average (EMA)** - Weighted moving average
- **Hull Moving Average (HMA)** - Fast and smooth moving average
- **Double Exponential Moving Average (DEMA)** - Reduced lag moving average
- **Triple Exponential Moving Average (TEMA)** - Triple smoothing for reduced lag
- **Adaptive Moving Average (AMA)** - Adaptive smoothing based on market efficiency
- **Arnaud Legoux Moving Average (ALMA)** - Gaussian-weighted moving average
- **Volume Weighted Moving Average (VWMA)** - Volume-weighted price average
- **Linear Regression** - Linear trend analysis

### Oscillator Indicators
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

### Momentum Indicators
- **Momentum** - Rate of price change
- **Rate of Change (ROC)** - Percentage price change over period
- **Price Rate of Change (PROC)** - Price momentum indicator
- **Detrended Price Oscillator (DPO)** - Price deviation from trend
- **Percentage Price Oscillator (PPO)** - Percentage difference between EMAs
- **Ease of Movement (EOM)** - Volume-weighted momentum

### Volatility Indicators
- **Average True Range (ATR)** - Market volatility measure
- **Standard Deviation** - Price volatility measure
- **Historical Volatility** - Statistical volatility calculation
- **Chaikin Volatility** - Volume-weighted volatility
- **Ulcer Index** - Downside volatility measure

### Multi-Parameter Trend Indicators
- **Bollinger Bands** - Volatility-based support/resistance
- **Keltner Channels** - ATR-based price channels
- **Donchian Channels** - High-low price channels
- **Parabolic SAR** - Trend following stop-loss indicator
- **Ichimoku Cloud** - Multi-component trend indicator
- **Gator Oscillator** - Jaw, teeth, and lips oscillator

### Complex Indicators
- **MACD** - Moving Average Convergence Divergence
- **Average Directional Index (ADX)** - Trend strength indicator
- **Know Sure Thing (KST)** - Long-term momentum oscillator
- **Coppock Curve** - Long-term momentum indicator
- **Vortex Indicator** - Trend reversal detection

### Volume Indicators
- **Money Flow Index (MFI)** - Volume-weighted RSI
- **Chaikin Money Flow (CMF)** - Volume-weighted price oscillator
- **Volume Rate of Change** - Volume momentum indicator
- **Volume Price Trend (VPT)** - Cumulative volume-price indicator
- **Negative Volume Index (NVI)** - Volume-based trend indicator
- **Positive Volume Index (PVI)** - Volume-based trend indicator
- **Money Flow Volume (MFV)** - Volume-weighted price flow
- **Enhanced VWAP** - Advanced volume-weighted average price

### Support and Resistance Indicators
- **Pivot Points** - Key support/resistance levels
- **Fibonacci Retracements** - Golden ratio retracement levels
- **Price Channels** - Dynamic support/resistance channels
- **Andrews Pitchfork** - Trend channel indicator

### Utility Indicators
- **Wilder's Smoothing** - Smoothing algorithm for indicators