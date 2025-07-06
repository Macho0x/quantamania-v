# Technical Indicators Configuration System

The V Language Technical Indicators Library now includes a comprehensive configuration system that provides type safety, parameter validation, and easy customization for all indicators.

## Overview

Each technical indicator has its own configuration struct that defines:
- **Default parameters** for common use cases
- **Validation rules** to ensure parameter correctness
- **Type safety** to prevent runtime errors
- **Clear error messages** for invalid configurations

## Available Configuration Structs

### Trend Indicators
- `SMAConfig` - Simple Moving Average
- `EMAConfig` - Exponential Moving Average
- `HMAConfig` - Hull Moving Average
- `DEMAConfig` - Double Exponential Moving Average
- `TEMAConfig` - Triple Exponential Moving Average
- `AMAConfig` - Adaptive Moving Average
- `ALMAConfig` - Arnaud Legoux Moving Average
- `VWMAConfig` - Volume Weighted Moving Average
- `LinearRegressionConfig` - Linear Regression

### Oscillator Indicators
- `RSIConfig` - Relative Strength Index
- `CCIConfig` - Commodity Channel Index
- `WilliamsRConfig` - Williams %R
- `StochasticConfig` - Stochastic Oscillator
- `StochasticRSIConfig` - Stochastic RSI
- `AwesomeOscillatorConfig` - Awesome Oscillator
- `UltimateOscillatorConfig` - Ultimate Oscillator
- `TRIXConfig` - TRIX
- `CMOConfig` - Chande Momentum Oscillator
- `FisherConfig` - Fisher Transform

### Momentum Indicators
- `MomentumConfig` - Momentum
- `ROCConfig` - Rate of Change
- `PROCConfig` - Price Rate of Change
- `DPOConfig` - Detrended Price Oscillator
- `PPOConfig` - Percentage Price Oscillator
- `EOMConfig` - Ease of Movement

### Volatility Indicators
- `ATRConfig` - Average True Range
- `StdDevConfig` - Standard Deviation
- `HistoricalVolatilityConfig` - Historical Volatility
- `ChaikinVolatilityConfig` - Chaikin Volatility
- `UlcerIndexConfig` - Ulcer Index

### Multi-Parameter Trend Indicators
- `BollingerConfig` - Bollinger Bands (period, standard deviation)
- `KeltnerConfig` - Keltner Channels (period, ATR multiplier)
- `DonchianConfig` - Donchian Channels (period)
- `ParabolicSARConfig` - Parabolic SAR (acceleration, max acceleration)
- `IchimokuConfig` - Ichimoku Cloud (3 periods)
- `GatorConfig` - Gator Oscillator (jaw, teeth, lips periods)

### Complex Indicators
- `MACDConfig` - MACD (short period, long period, signal period)
- `ADXConfig` - Average Directional Index (period)
- `KSTConfig` - Know Sure Thing (4 ROC periods, 4 SMA periods, signal period)
- `CoppockConfig` - Coppock Curve (2 ROC periods, WMA period)
- `VortexConfig` - Vortex Indicator (period)

### Volume Indicators
- `MFIConfig` - Money Flow Index
- `CMFConfig` - Chaikin Money Flow
- `VolumeROCConfig` - Volume Rate of Change
- `VPTConfig` - Volume Price Trend
- `NVIConfig` - Negative Volume Index
- `PVIConfig` - Positive Volume Index
- `MFVConfig` - Money Flow Volume
- `EnhancedVWAPConfig` - Enhanced Volume Weighted Average Price

### Support and Resistance Indicators
- `PivotPointsConfig` - Pivot Points
- `FibonacciConfig` - Fibonacci Retracements (lookback period)
- `PriceChannelsConfig` - Price Channels (period)
- `AndrewsPitchforkConfig` - Andrews Pitchfork

### Utility Indicators
- `WildersConfig` - Wilder's Smoothing

## Usage Examples

### 1. Using Default Configurations

```v
import indicators

// Get default configuration
sma_config := indicators.default_sma_config()
if validated_config := sma_config.validate() {
    result := indicators.sma(data, validated_config.period)
    println('SMA: ${result}')
}
```

### 2. Custom Configurations

```v
// Create custom configuration
custom_sma := indicators.SMAConfig{period: 10}
if validated_config := custom_sma.validate() {
    result := indicators.sma(data, validated_config.period)
    println('Custom SMA: ${result}')
}
```

### 3. Complex Indicator Configuration

```v
// MACD with custom parameters
macd_config := indicators.MACDConfig{
    short_period: 8
    long_period: 21
    signal_period: 5
}

if validated_config := macd_config.validate() {
    macd_line, signal_line, histogram := indicators.macd(data, 
        validated_config.short_period, 
        validated_config.long_period, 
        validated_config.signal_period)
    println('MACD: ${macd_line}')
}
```

### 4. Advanced Moving Averages

```v
// Hull Moving Average
hma_config := indicators.HMAConfig{period: 14}
if validated_config := hma_config.validate() {
    result := indicators.hull_moving_average(data, validated_config.period)
    println('HMA: ${result}')
}

// Arnaud Legoux Moving Average
alma_config := indicators.ALMAConfig{
    period: 20
    sigma: 6.0
    offset: 0.85
}
if validated_config := alma_config.validate() {
    result := indicators.arnaud_legoux_moving_average(data, 
        validated_config.period, 
        validated_config.sigma, 
        validated_config.offset)
    println('ALMA: ${result}')
}
```

### 5. Volume-Based Indicators

```v
// Enhanced VWAP
enhanced_vwap_config := indicators.EnhancedVWAPConfig{period: 20}
if validated_config := enhanced_vwap_config.validate() {
    result := indicators.enhanced_vwap(data, validated_config.period)
    println('Enhanced VWAP: ${result}')
}

// Money Flow Index
mfi_config := indicators.MFIConfig{period: 14}
if validated_config := mfi_config.validate() {
    result := indicators.money_flow_index(high, low, close, volume, validated_config.period)
    println('MFI: ${result}')
}
```

### 6. Error Handling

```v
// Invalid configuration will be caught
invalid_sma := indicators.SMAConfig{period: -5}
if validated_config := invalid_sma.validate() {
    result := indicators.sma(data, validated_config.period)
} else {
    println('Error: Invalid SMA configuration')
}
```

## Configuration Validation

Each configuration struct implements a `validate()` method that returns:
- **Success**: The validated configuration
- **Error**: An error message describing the validation failure

### Common Validation Rules

- **Periods**: Must be positive integers
- **Standard deviations**: Must be positive numbers
- **MACD periods**: Short period must be less than long period
- **Acceleration values**: Must be positive and within bounds
- **ALMA offset**: Must be between 0 and 1
- **Volume indices**: Must have positive periods

## Default Values

All configurations come with sensible defaults:

### Trend Indicators
| Indicator | Default Period | Other Defaults |
|-----------|----------------|----------------|
| SMA | 20 | - |
| EMA | 20 | - |
| HMA | 20 | - |
| DEMA | 20 | - |
| TEMA | 20 | - |
| AMA | 2, 30 | fast, slow |
| ALMA | 20 | 6.0 sigma, 0.85 offset |
| VWMA | 20 | - |
| Linear Regression | 20 | - |

### Oscillator Indicators
| Indicator | Default Period | Other Defaults |
|-----------|----------------|----------------|
| RSI | 14 | - |
| CCI | 20 | - |
| Williams %R | 14 | - |
| Stochastic | 14, 3 | K, D |
| Stochastic RSI | 14, 14, 3 | RSI, K, D |
| Awesome Oscillator | 5, 34 | short, long |
| Ultimate Oscillator | 7, 14, 28 | period1, period2, period3 |
| TRIX | 15 | - |
| CMO | 14 | - |
| Fisher Transform | 10 | - |

### Momentum Indicators
| Indicator | Default Period | Other Defaults |
|-----------|----------------|----------------|
| Momentum | 10 | - |
| ROC | 10 | - |
| PROC | 10 | - |
| DPO | 20 | - |
| PPO | 12, 26, 9 | fast, slow, signal |
| EOM | 14 | - |

### Volatility Indicators
| Indicator | Default Period | Other Defaults |
|-----------|----------------|----------------|
| ATR | 14 | - |
| Standard Deviation | 20 | - |
| Historical Volatility | 20 | - |
| Chaikin Volatility | 10 | - |
| Ulcer Index | 14 | - |

### Multi-Parameter Indicators
| Indicator | Default Period | Other Defaults |
|-----------|----------------|----------------|
| Bollinger | 20 | 2.0 std dev |
| Keltner | 20 | 2.0 ATR multiplier |
| Donchian | 20 | - |
| Parabolic SAR | - | 0.02 accel, 0.2 max accel |
| Ichimoku | 9, 26, 52 | tenkan, kijun, senkou |
| Gator | 13, 8, 5 | jaw, teeth, lips |

### Complex Indicators
| Indicator | Default Period | Other Defaults |
|-----------|----------------|----------------|
| MACD | 12, 26, 9 | short, long, signal |
| ADX | 14 | - |
| KST | 10, 15, 20, 30 | ROC1-4 |
| KST | 10, 10, 10, 15 | SMA1-4 |
| KST | 9 | signal |
| Coppock | 14, 11, 10 | ROC1, ROC2, WMA |

### Volume Indicators
| Indicator | Default Period | Other Defaults |
|-----------|----------------|----------------|
| MFI | 14 | - |
| CMF | 20 | - |
| Volume ROC | 25 | - |
| VPT | 14 | - |
| NVI | 255 | - |
| PVI | 255 | - |
| MFV | 14 | - |
| Enhanced VWAP | 20 | - |

### Support and Resistance
| Indicator | Default Period | Other Defaults |
|-----------|----------------|----------------|
| Pivot Points | - | - |
| Fibonacci | 20 | lookback |
| Price Channels | 20 | - |
| Andrews Pitchfork | - | - |

## Benefits

1. **Type Safety**: Compile-time checking of parameter types
2. **Validation**: Runtime validation of parameter values
3. **Documentation**: Self-documenting code with clear parameter names
4. **Maintainability**: Easy to modify and extend configurations
5. **Error Handling**: Clear error messages for debugging
6. **Consistency**: Standardized approach across all indicators

## Migration from Direct Parameters

### Before (Old Way)
```v
result := indicators.sma(data, 20)
macd_line, signal_line, histogram := indicators.macd(data, 12, 26, 9)
hma_result := indicators.hull_moving_average(data, 14)
```

### After (New Way)
```v
config := indicators.SMAConfig{period: 20}
if validated_config := config.validate() {
    result := indicators.sma(data, validated_config.period)
}

macd_config := indicators.MACDConfig{short_period: 12, long_period: 26, signal_period: 9}
if validated_config := macd_config.validate() {
    macd_line, signal_line, histogram := indicators.macd(data, 
        validated_config.short_period, 
        validated_config.long_period, 
        validated_config.signal_period)
}

hma_config := indicators.HMAConfig{period: 14}
if validated_config := hma_config.validate() {
    hma_result := indicators.hull_moving_average(data, validated_config.period)
}
```

## Running Examples

To see the configuration system in action:

```bash
v run examples/config_example.v
```

This will demonstrate various configuration patterns and error handling scenarios. 