import indicators

fn main() {
    println('V Language Technical Indicators Library')
    println('=====================================')
    println('Available indicators:')
    println('1. Simple Moving Average (SMA)')
    println('2. Exponential Moving Average (EMA)')
    println('3. Bollinger Bands')
    println('4. Relative Strength Index (RSI)')
    println('5. Average Directional Index (ADX)')
    println('6. Moving Average Convergence Divergence (MACD)')
    println('7. Parabolic SAR')
    println('8. Ichimoku Cloud')
    println('9. Stochastic Oscillator')
    println('10. Williams %R')
    println('11. Commodity Channel Index (CCI)')
    println('12. On-Balance Volume (OBV)')
    println('13. Accumulation/Distribution Line')
    println('14. Chaikin Money Flow')
    println('15. Average True Range (ATR)')
    println('16. Keltner Channels')
    println('17. Volume Weighted Average Price (VWAP)')
    println('18. Awesome Oscillator')
    println('19. Ultimate Oscillator')
    println('20. TRIX')
    println('21. Donchian Channels')
    println('22. Wilder\'s Smoothing')
    println('23. Rate of Change (ROC)')
    println('24. Money Flow Index')
    println('25. Stochastic RSI')
    println('26. Know Sure Thing (KST)')
    println('27. Coppock Curve')
    println('28. Vortex Indicator')
    println('29. Hull Moving Average (HMA)')
    println('30. Linear Regression')
    println('31. Volume Weighted Moving Average (VWMA)')
    println('32. Double Exponential Moving Average (DEMA)')
    println('33. Triple Exponential Moving Average (TEMA)')
    println('34. Adaptive Moving Average (AMA)')
    println('35. Arnaud Legoux Moving Average (ALMA)')
    println('36. Momentum')
    println('37. Price Rate of Change (PROC)')
    println('38. Detrended Price Oscillator (DPO)')
    println('39. Percentage Price Oscillator (PPO)')
    println('40. Chande Momentum Oscillator (CMO)')
    println('41. Fisher Transform')
    println('42. Ease of Movement (EOM)')
    println('43. Standard Deviation')
    println('44. Historical Volatility')
    println('45. Chaikin Volatility')
    println('46. Ulcer Index')
    println('47. Gator Oscillator')
    println('48. Volume Rate of Change (Volume ROC)')
    println('49. Volume Price Trend (VPT)')
    println('50. Negative Volume Index (NVI)')
    println('51. Positive Volume Index (PVI)')
    println('52. Money Flow Volume (MFV)')
    println('53. Enhanced VWAP')
    println('54. Pivot Points')
    println('55. Fibonacci Retracements')
    println('56. Price Channels')
    println('57. Andrews Pitchfork')
    
    // Use a hardcoded choice for testing
    choice := 1

    match choice {
        1 {
            data := [
                indicators.OHLCV{open: 1.0, high: 1.0, low: 1.0, close: 1.0, volume: 0.0},
                indicators.OHLCV{open: 1.0, high: 2.0, low: 1.0, close: 2.0, volume: 0.0},
                indicators.OHLCV{open: 2.0, high: 3.0, low: 2.0, close: 3.0, volume: 0.0},
                indicators.OHLCV{open: 3.0, high: 4.0, low: 3.0, close: 4.0, volume: 0.0},
                indicators.OHLCV{open: 4.0, high: 5.0, low: 4.0, close: 5.0, volume: 0.0},
                indicators.OHLCV{open: 5.0, high: 6.0, low: 5.0, close: 6.0, volume: 0.0},
                indicators.OHLCV{open: 6.0, high: 7.0, low: 6.0, close: 7.0, volume: 0.0},
                indicators.OHLCV{open: 7.0, high: 8.0, low: 7.0, close: 8.0, volume: 0.0},
                indicators.OHLCV{open: 8.0, high: 9.0, low: 8.0, close: 9.0, volume: 0.0},
                indicators.OHLCV{open: 9.0, high: 10.0, low: 9.0, close: 10.0, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.SMAConfig{period: 5}
            if validated_config := config.validate() {
                result := indicators.sma(data, validated_config)
                println('SMA Configuration: ${config}')
                println('SMA Result: ${result}')
            } else {
                println('Invalid SMA configuration: ${config}')
            }
        }
        2 {
            data := [
                indicators.OHLCV{open: 1.0, high: 1.0, low: 1.0, close: 1.0, volume: 0.0},
                indicators.OHLCV{open: 1.0, high: 2.0, low: 1.0, close: 2.0, volume: 0.0},
                indicators.OHLCV{open: 2.0, high: 3.0, low: 2.0, close: 3.0, volume: 0.0},
                indicators.OHLCV{open: 3.0, high: 4.0, low: 3.0, close: 4.0, volume: 0.0},
                indicators.OHLCV{open: 4.0, high: 5.0, low: 4.0, close: 5.0, volume: 0.0},
                indicators.OHLCV{open: 5.0, high: 6.0, low: 5.0, close: 6.0, volume: 0.0},
                indicators.OHLCV{open: 6.0, high: 7.0, low: 6.0, close: 7.0, volume: 0.0},
                indicators.OHLCV{open: 7.0, high: 8.0, low: 7.0, close: 8.0, volume: 0.0},
                indicators.OHLCV{open: 8.0, high: 9.0, low: 8.0, close: 9.0, volume: 0.0},
                indicators.OHLCV{open: 9.0, high: 10.0, low: 9.0, close: 10.0, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.EMAConfig{period: 5}
            if validated_config := config.validate() {
                result := indicators.ema(data, validated_config)
                println('EMA Configuration: ${config}')
                println('EMA Result: ${result}')
            } else {
                println('Invalid EMA configuration: ${config}')
            }
        }
        3 {
            data := [
                indicators.OHLCV{open: 1.0, high: 1.0, low: 1.0, close: 1.0, volume: 0.0},
                indicators.OHLCV{open: 2.0, high: 2.0, low: 2.0, close: 2.0, volume: 0.0},
                indicators.OHLCV{open: 3.0, high: 3.0, low: 3.0, close: 3.0, volume: 0.0},
                indicators.OHLCV{open: 4.0, high: 4.0, low: 4.0, close: 4.0, volume: 0.0},
                indicators.OHLCV{open: 5.0, high: 5.0, low: 5.0, close: 5.0, volume: 0.0},
                indicators.OHLCV{open: 6.0, high: 6.0, low: 6.0, close: 6.0, volume: 0.0},
                indicators.OHLCV{open: 7.0, high: 7.0, low: 7.0, close: 7.0, volume: 0.0},
                indicators.OHLCV{open: 8.0, high: 8.0, low: 8.0, close: 8.0, volume: 0.0},
                indicators.OHLCV{open: 9.0, high: 9.0, low: 9.0, close: 9.0, volume: 0.0},
                indicators.OHLCV{open: 10.0, high: 10.0, low: 10.0, close: 10.0, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.BollingerConfig{period: 5, num_std_dev: 2.0}
            if validated_config := config.validate() {
                upper, middle, lower := indicators.bollinger_bands(data, validated_config)
                println('Bollinger Configuration: ${config}')
                println('Upper Band: ${upper}')
                println('Middle Band: ${middle}')
                println('Lower Band: ${lower}')
            } else {
                println('Invalid Bollinger configuration: ${config}')
            }
        }
        4 {
            data := [
                indicators.OHLCV{open: 44.34, high: 44.34, low: 44.34, close: 44.34, volume: 0.0},
                indicators.OHLCV{open: 44.09, high: 44.09, low: 44.09, close: 44.09, volume: 0.0},
                indicators.OHLCV{open: 44.15, high: 44.15, low: 44.15, close: 44.15, volume: 0.0},
                indicators.OHLCV{open: 43.61, high: 43.61, low: 43.61, close: 43.61, volume: 0.0},
                indicators.OHLCV{open: 44.33, high: 44.33, low: 44.33, close: 44.33, volume: 0.0},
                indicators.OHLCV{open: 44.83, high: 44.83, low: 44.83, close: 44.83, volume: 0.0},
                indicators.OHLCV{open: 45.10, high: 45.10, low: 45.10, close: 45.10, volume: 0.0},
                indicators.OHLCV{open: 45.42, high: 45.42, low: 45.42, close: 45.42, volume: 0.0},
                indicators.OHLCV{open: 45.84, high: 45.84, low: 45.84, close: 45.84, volume: 0.0},
                indicators.OHLCV{open: 46.08, high: 46.08, low: 46.08, close: 46.08, volume: 0.0},
                indicators.OHLCV{open: 45.89, high: 45.89, low: 45.89, close: 45.89, volume: 0.0},
                indicators.OHLCV{open: 46.03, high: 46.03, low: 46.03, close: 46.03, volume: 0.0},
                indicators.OHLCV{open: 45.61, high: 45.61, low: 45.61, close: 45.61, volume: 0.0},
                indicators.OHLCV{open: 46.28, high: 46.28, low: 46.28, close: 46.28, volume: 0.0},
                indicators.OHLCV{open: 46.28, high: 46.28, low: 46.28, close: 46.28, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.RSIConfig{period: 14}
            if validated_config := config.validate() {
                result := indicators.rsi(data, validated_config)
                println('RSI Configuration: ${config}')
                println('RSI Result: ${result}')
            } else {
                println('Invalid RSI configuration: ${config}')
            }
        }
        5 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0}, indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0}, indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0}, indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0}, indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0}, indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0}, indicators.OHLCV{open: 23.01, high: 23.36, low: 22.91, close: 23.01, volume: 0.0},
                indicators.OHLCV{open: 22.81, high: 23.13, low: 22.65, close: 22.81, volume: 0.0}, indicators.OHLCV{open: 23.36, high: 23.43, low: 22.81, close: 23.36, volume: 0.0},
                indicators.OHLCV{open: 23.31, high: 23.48, low: 23.15, close: 23.31, volume: 0.0}, indicators.OHLCV{open: 23.23, high: 23.43, low: 23.05, close: 23.23, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.28, low: 22.88, close: 23.11, volume: 0.0}, indicators.OHLCV{open: 23.01, high: 23.18, low: 22.85, close: 23.01, volume: 0.0},
                indicators.OHLCV{open: 23.28, high: 23.33, low: 22.93, close: 23.28, volume: 0.0}, indicators.OHLCV{open: 23.13, high: 23.23, low: 22.98, close: 23.13, volume: 0.0},
                indicators.OHLCV{open: 23.08, high: 23.16, low: 22.83, close: 23.08, volume: 0.0}, indicators.OHLCV{open: 22.81, high: 23.06, low: 22.75, close: 22.81, volume: 0.0},
                indicators.OHLCV{open: 22.56, high: 22.86, low: 22.43, close: 22.56, volume: 0.0}, indicators.OHLCV{open: 22.31, high: 22.58, low: 22.24, close: 22.31, volume: 0.0},
                indicators.OHLCV{open: 22.58, high: 22.68, low: 22.27, close: 22.58, volume: 0.0}, indicators.OHLCV{open: 22.28, high: 22.51, low: 22.15, close: 22.28, volume: 0.0},
            ]
            period := 14
            adx_config := indicators.ADXConfig{period: period}
            adx_line, plus_di, minus_di := indicators.adx(data, adx_config)
            println('ADX: ${adx_line}')
            println('+DI: ${plus_di}')
            println('-DI: ${minus_di}')
        }
        6 {
            data := [
                indicators.OHLCV{open: 22.27, high: 22.27, low: 22.27, close: 22.27, volume: 0.0},
                indicators.OHLCV{open: 22.19, high: 22.19, low: 22.19, close: 22.19, volume: 0.0},
                indicators.OHLCV{open: 22.08, high: 22.08, low: 22.08, close: 22.08, volume: 0.0},
                indicators.OHLCV{open: 22.17, high: 22.17, low: 22.17, close: 22.17, volume: 0.0},
                indicators.OHLCV{open: 22.18, high: 22.18, low: 22.18, close: 22.18, volume: 0.0},
                indicators.OHLCV{open: 22.13, high: 22.13, low: 22.13, close: 22.13, volume: 0.0},
                indicators.OHLCV{open: 22.23, high: 22.23, low: 22.23, close: 22.23, volume: 0.0},
                indicators.OHLCV{open: 22.43, high: 22.43, low: 22.43, close: 22.43, volume: 0.0},
                indicators.OHLCV{open: 22.24, high: 22.24, low: 22.24, close: 22.24, volume: 0.0},
                indicators.OHLCV{open: 22.29, high: 22.29, low: 22.29, close: 22.29, volume: 0.0},
                indicators.OHLCV{open: 22.15, high: 22.15, low: 22.15, close: 22.15, volume: 0.0},
                indicators.OHLCV{open: 22.39, high: 22.39, low: 22.39, close: 22.39, volume: 0.0},
                indicators.OHLCV{open: 22.38, high: 22.38, low: 22.38, close: 22.38, volume: 0.0},
                indicators.OHLCV{open: 22.61, high: 22.61, low: 22.61, close: 22.61, volume: 0.0},
                indicators.OHLCV{open: 23.36, high: 23.36, low: 23.36, close: 23.36, volume: 0.0},
                indicators.OHLCV{open: 24.05, high: 24.05, low: 24.05, close: 24.05, volume: 0.0},
                indicators.OHLCV{open: 23.75, high: 23.75, low: 23.75, close: 23.75, volume: 0.0},
                indicators.OHLCV{open: 23.83, high: 23.83, low: 23.83, close: 23.83, volume: 0.0},
                indicators.OHLCV{open: 23.95, high: 23.95, low: 23.95, close: 23.95, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.63, low: 23.63, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.82, high: 23.82, low: 23.82, close: 23.82, volume: 0.0},
                indicators.OHLCV{open: 23.87, high: 23.87, low: 23.87, close: 23.87, volume: 0.0},
                indicators.OHLCV{open: 23.65, high: 23.65, low: 23.65, close: 23.65, volume: 0.0},
                indicators.OHLCV{open: 23.19, high: 23.19, low: 23.19, close: 23.19, volume: 0.0},
                indicators.OHLCV{open: 23.10, high: 23.10, low: 23.10, close: 23.10, volume: 0.0},
                indicators.OHLCV{open: 23.33, high: 23.33, low: 23.33, close: 23.33, volume: 0.0},
                indicators.OHLCV{open: 22.68, high: 22.68, low: 22.68, close: 22.68, volume: 0.0},
                indicators.OHLCV{open: 23.10, high: 23.10, low: 23.10, close: 23.10, volume: 0.0},
                indicators.OHLCV{open: 22.40, high: 22.40, low: 22.40, close: 22.40, volume: 0.0},
                indicators.OHLCV{open: 22.17, high: 22.17, low: 22.17, close: 22.17, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.MACDConfig{short_period: 12, long_period: 26, signal_period: 9}
            if validated_config := config.validate() {
                macd_line, signal_line, histogram := indicators.macd(data, validated_config)
                println('MACD Configuration: ${config}')
                println('MACD Line: ${macd_line}')
                println('Signal Line: ${signal_line}')
                println('Histogram: ${histogram}')
            } else {
                println('Invalid MACD configuration: ${config}')
            }
        }
        7 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0}, indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0}, indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0}, indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
            ]
            acceleration := 0.02
            max_acceleration := 0.2
            sar_config := indicators.ParabolicSARConfig{acceleration: acceleration, max_acceleration: max_acceleration}
            sar := indicators.parabolic_sar(data, sar_config)
            println('Parabolic SAR: ${sar}')
        }
        8 {
            data := [
                indicators.OHLCV{open: 49, high: 50, low: 48, close: 49, volume: 0.0}, indicators.OHLCV{open: 50, high: 51, low: 49, close: 50, volume: 0.0},
                indicators.OHLCV{open: 51, high: 52, low: 50, close: 51, volume: 0.0}, indicators.OHLCV{open: 52, high: 53, low: 51, close: 52, volume: 0.0},
                indicators.OHLCV{open: 53, high: 54, low: 52, close: 53, volume: 0.0}, indicators.OHLCV{open: 54, high: 55, low: 53, close: 54, volume: 0.0},
                indicators.OHLCV{open: 55, high: 56, low: 54, close: 55, volume: 0.0}, indicators.OHLCV{open: 56, high: 57, low: 55, close: 56, volume: 0.0},
                indicators.OHLCV{open: 57, high: 58, low: 56, close: 57, volume: 0.0}, indicators.OHLCV{open: 58, high: 59, low: 57, close: 58, volume: 0.0},
                indicators.OHLCV{open: 59, high: 60, low: 58, close: 59, volume: 0.0}, indicators.OHLCV{open: 60, high: 61, low: 59, close: 60, volume: 0.0},
                indicators.OHLCV{open: 61, high: 62, low: 60, close: 61, volume: 0.0}, indicators.OHLCV{open: 62, high: 63, low: 61, close: 62, volume: 0.0},
                indicators.OHLCV{open: 63, high: 64, low: 62, close: 63, volume: 0.0}, indicators.OHLCV{open: 64, high: 65, low: 63, close: 64, volume: 0.0},
                indicators.OHLCV{open: 65, high: 66, low: 64, close: 65, volume: 0.0}, indicators.OHLCV{open: 66, high: 67, low: 65, close: 66, volume: 0.0},
                indicators.OHLCV{open: 67, high: 68, low: 66, close: 67, volume: 0.0}, indicators.OHLCV{open: 68, high: 69, low: 67, close: 68, volume: 0.0},
                indicators.OHLCV{open: 69, high: 70, low: 68, close: 69, volume: 0.0}, indicators.OHLCV{open: 70, high: 71, low: 69, close: 70, volume: 0.0},
                indicators.OHLCV{open: 71, high: 72, low: 70, close: 71, volume: 0.0}, indicators.OHLCV{open: 72, high: 73, low: 71, close: 72, volume: 0.0},
                indicators.OHLCV{open: 73, high: 74, low: 72, close: 73, volume: 0.0}, indicators.OHLCV{open: 74, high: 75, low: 73, close: 74, volume: 0.0},
                indicators.OHLCV{open: 75, high: 76, low: 74, close: 75, volume: 0.0}, indicators.OHLCV{open: 76, high: 77, low: 75, close: 76, volume: 0.0},
                indicators.OHLCV{open: 77, high: 78, low: 76, close: 77, volume: 0.0}, indicators.OHLCV{open: 78, high: 79, low: 77, close: 78, volume: 0.0},
                indicators.OHLCV{open: 79, high: 80, low: 78, close: 79, volume: 0.0}, indicators.OHLCV{open: 80, high: 81, low: 79, close: 80, volume: 0.0},
            ]
            tenkan_period := 9
            kijun_period := 26
            senkou_b_period := 52
            ichimoku_config := indicators.IchimokuConfig{tenkan_period: tenkan_period, kijun_period: kijun_period, senkou_b_period: senkou_b_period}
            tenkan, kijun, senkou_a, senkou_b, chikou := indicators.ichimoku_cloud(data, ichimoku_config)
            println('Tenkan-sen: ${tenkan}')
            println('Kijun-sen: ${kijun}')
            println('Senkou Span A: ${senkou_a}')
            println('Senkou Span B: ${senkou_b}')
            println('Chikou Span: ${chikou}')
        }
        9 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0}, indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0}, indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0}, indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0}, indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0}, indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            k_period := 14
            d_period := 3
            stochastic_config := indicators.StochasticConfig{k_period: k_period, d_period: d_period}
            k_line, d_line := indicators.stochastic_oscillator(data, stochastic_config)
            println('%K Line: ${k_line}')
            println('%D Line: ${d_line}')
        }
        10 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0}, indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0}, indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0}, indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0}, indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0}, indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            period := 14
            williams_config := indicators.WilliamsRConfig{period: period}
            result := indicators.williams_percent_r(data, williams_config)
            println('Williams %R: ${result}')
        }
        11 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0}, indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0}, indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0}, indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0}, indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0}, indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0}, indicators.OHLCV{open: 23.01, high: 23.36, low: 22.91, close: 23.01, volume: 0.0},
                indicators.OHLCV{open: 22.81, high: 23.13, low: 22.65, close: 22.81, volume: 0.0}, indicators.OHLCV{open: 23.36, high: 23.43, low: 22.81, close: 23.36, volume: 0.0},
                indicators.OHLCV{open: 23.31, high: 23.48, low: 23.15, close: 23.31, volume: 0.0}, indicators.OHLCV{open: 23.23, high: 23.43, low: 23.05, close: 23.23, volume: 0.0},
            ]
            period := 20
            cci_config := indicators.CCIConfig{period: period}
            result := indicators.cci(data, cci_config)
            println('CCI: ${result}')
        }
        12 {
            data := [
                indicators.OHLCV{high: 23.98, low: 23.52, close: 23.66, volume: 10000},
                indicators.OHLCV{high: 23.71, low: 23.33, close: 23.61, volume: 12000},
                indicators.OHLCV{high: 23.91, low: 23.21, close: 23.85, volume: 15000},
                indicators.OHLCV{high: 24.83, low: 23.87, close: 24.62, volume: 20000},
                indicators.OHLCV{high: 24.73, low: 24.22, close: 24.25, volume: 18000},
                indicators.OHLCV{high: 24.48, low: 23.82, close: 24.18, volume: 17000},
            ]
            result := indicators.on_balance_volume(data)
            println('On-Balance Volume: ${result}')
        }
        13 {
            data := [
                indicators.OHLCV{high: 23.98, low: 23.52, close: 23.66, volume: 10000},
                indicators.OHLCV{high: 23.71, low: 23.33, close: 23.61, volume: 12000},
                indicators.OHLCV{high: 23.91, low: 23.21, close: 23.85, volume: 15000},
                indicators.OHLCV{high: 24.83, low: 23.87, close: 24.62, volume: 20000},
                indicators.OHLCV{high: 24.73, low: 24.22, close: 24.25, volume: 18000},
                indicators.OHLCV{high: 24.48, low: 23.82, close: 24.18, volume: 17000},
                indicators.OHLCV{high: 24.28, low: 23.64, close: 24.11, volume: 16000},
                indicators.OHLCV{high: 24.41, low: 23.88, close: 24.35, volume: 19000},
                indicators.OHLCV{high: 24.36, low: 24.01, close: 24.11, volume: 14000},
                indicators.OHLCV{high: 24.38, low: 23.73, close: 23.76, volume: 21000},
                indicators.OHLCV{high: 24.08, low: 23.58, close: 24.03, volume: 22000},
                indicators.OHLCV{high: 23.91, low: 23.43, close: 23.63, volume: 25000},
                indicators.OHLCV{high: 23.83, low: 23.21, close: 23.73, volume: 23000},
                indicators.OHLCV{high: 23.51, low: 22.92, close: 23.06, volume: 30000},
                indicators.OHLCV{high: 23.31, low: 22.68, close: 23.11, volume: 28000},
                indicators.OHLCV{high: 23.36, low: 22.91, close: 23.01, volume: 26000},
                indicators.OHLCV{high: 23.13, low: 22.65, close: 22.81, volume: 32000},
                indicators.OHLCV{high: 23.43, low: 22.81, close: 23.36, volume: 29000},
                indicators.OHLCV{high: 23.48, low: 23.15, close: 23.31, volume: 27000},
                indicators.OHLCV{high: 23.43, low: 23.05, close: 23.23, volume: 24000},
            ]
            period := 20
            cmf_config := indicators.CMFConfig{period: period}
            result := indicators.chaikin_money_flow(data, cmf_config)
            println('Chaikin Money Flow: ${result}')
        }
        14 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0}, indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0}, indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0}, indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0}, indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0}, indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            period := 14
            atr_config := indicators.ATRConfig{period: period}
            result := indicators.average_true_range(data, atr_config)
            println('Average True Range: ${result}')
        }
        15 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0}, indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0}, indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0}, indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0}, indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0}, indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0}, indicators.OHLCV{open: 23.01, high: 23.36, low: 22.91, close: 23.01, volume: 0.0},
                indicators.OHLCV{open: 22.81, high: 23.13, low: 22.65, close: 22.81, volume: 0.0}, indicators.OHLCV{open: 23.36, high: 23.43, low: 22.81, close: 23.36, volume: 0.0},
                indicators.OHLCV{open: 23.31, high: 23.48, low: 23.15, close: 23.31, volume: 0.0}, indicators.OHLCV{open: 23.23, high: 23.43, low: 23.05, close: 23.23, volume: 0.0},
            ]
            period := 20
            atr_multiplier := 2.0
            keltner_config := indicators.KeltnerConfig{period: period, atr_multiplier: atr_multiplier}
            upper, middle, lower := indicators.keltner_channels(data, keltner_config)
            println('Upper Keltner Channel: ${upper}')
            println('Middle Keltner Channel: ${middle}')
            println('Lower Keltner Channel: ${lower}')
        }
        16 {
            data := [
                indicators.OHLCV{high: 23.98, low: 23.52, close: 23.66, volume: 10000},
                indicators.OHLCV{high: 23.71, low: 23.33, close: 23.61, volume: 12000},
                indicators.OHLCV{high: 23.91, low: 23.21, close: 23.85, volume: 15000},
                indicators.OHLCV{high: 24.83, low: 23.87, close: 24.62, volume: 20000},
                indicators.OHLCV{high: 24.73, low: 24.22, close: 24.25, volume: 18000},
                indicators.OHLCV{high: 24.48, low: 23.82, close: 24.25, volume: 17000},
            ]
            result := indicators.vwap(data)
            println('VWAP: ${result}')
        }
        17 {
            data := [
                indicators.OHLCV{high: 23.98, low: 23.52, close: 23.66, volume: 10000},
                indicators.OHLCV{high: 23.71, low: 23.33, close: 23.61, volume: 12000},
                indicators.OHLCV{high: 23.91, low: 23.21, close: 23.85, volume: 15000},
                indicators.OHLCV{high: 24.83, low: 23.87, close: 24.62, volume: 20000},
                indicators.OHLCV{high: 24.73, low: 24.22, close: 24.25, volume: 18000},
                indicators.OHLCV{high: 24.48, low: 23.82, close: 24.18, volume: 17000},
            ]
            result := indicators.accumulation_distribution_line(data)
            println('Accumulation/Distribution Line: ${result}')
        }
        18 {
            data := [
                indicators.OHLCV{open: 23.52, high: 23.98, low: 23.52, close: 23.52, volume: 0.0}, indicators.OHLCV{open: 23.33, high: 23.71, low: 23.33, close: 23.33, volume: 0.0},
                indicators.OHLCV{open: 23.21, high: 23.91, low: 23.21, close: 23.21, volume: 0.0}, indicators.OHLCV{open: 23.87, high: 24.83, low: 23.87, close: 23.87, volume: 0.0},
                indicators.OHLCV{open: 24.22, high: 24.73, low: 24.22, close: 24.22, volume: 0.0}, indicators.OHLCV{open: 23.82, high: 24.48, low: 23.82, close: 23.82, volume: 0.0},
                indicators.OHLCV{open: 23.64, high: 24.28, low: 23.64, close: 23.64, volume: 0.0}, indicators.OHLCV{open: 23.88, high: 24.41, low: 23.88, close: 23.88, volume: 0.0},
                indicators.OHLCV{open: 24.01, high: 24.36, low: 24.01, close: 24.01, volume: 0.0}, indicators.OHLCV{open: 23.73, high: 24.38, low: 23.73, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.58, high: 24.08, low: 23.58, close: 23.58, volume: 0.0}, indicators.OHLCV{open: 23.43, high: 23.91, low: 23.43, close: 23.43, volume: 0.0},
                indicators.OHLCV{open: 23.21, high: 23.83, low: 23.21, close: 23.21, volume: 0.0}, indicators.OHLCV{open: 22.92, high: 23.51, low: 22.92, close: 22.92, volume: 0.0},
                indicators.OHLCV{open: 22.68, high: 23.31, low: 22.68, close: 22.68, volume: 0.0}, indicators.OHLCV{open: 22.91, high: 23.36, low: 22.91, close: 22.91, volume: 0.0},
                indicators.OHLCV{open: 22.65, high: 23.13, low: 22.65, close: 22.65, volume: 0.0}, indicators.OHLCV{open: 22.81, high: 23.43, low: 22.81, close: 22.81, volume: 0.0},
                indicators.OHLCV{open: 23.15, high: 23.48, low: 23.15, close: 23.15, volume: 0.0}, indicators.OHLCV{open: 23.05, high: 23.43, low: 23.05, close: 23.05, volume: 0.0},
                indicators.OHLCV{open: 22.88, high: 23.28, low: 22.88, close: 22.88, volume: 0.0}, indicators.OHLCV{open: 22.85, high: 23.18, low: 22.85, close: 22.85, volume: 0.0},
                indicators.OHLCV{open: 22.93, high: 23.33, low: 22.93, close: 22.93, volume: 0.0}, indicators.OHLCV{open: 22.98, high: 23.23, low: 22.98, close: 22.98, volume: 0.0},
                indicators.OHLCV{open: 22.83, high: 23.16, low: 22.83, close: 22.83, volume: 0.0}, indicators.OHLCV{open: 22.75, high: 23.06, low: 22.75, close: 22.75, volume: 0.0},
                indicators.OHLCV{open: 22.43, high: 22.86, low: 22.43, close: 22.43, volume: 0.0}, indicators.OHLCV{open: 22.24, high: 22.58, low: 22.24, close: 22.24, volume: 0.0},
                indicators.OHLCV{open: 22.27, high: 22.68, low: 22.27, close: 22.27, volume: 0.0}, indicators.OHLCV{open: 22.15, high: 22.51, low: 22.15, close: 22.15, volume: 0.0},
                indicators.OHLCV{open: 22.15, high: 22.51, low: 22.15, close: 22.15, volume: 0.0}, indicators.OHLCV{open: 22.15, high: 22.51, low: 22.15, close: 22.15, volume: 0.0},
                indicators.OHLCV{open: 22.15, high: 22.51, low: 22.15, close: 22.15, volume: 0.0}, indicators.OHLCV{open: 22.15, high: 22.51, low: 22.15, close: 22.15, volume: 0.0},
            ]
            short_period := 5
            long_period := 34
            awesome_config := indicators.AwesomeOscillatorConfig{short_period: short_period, long_period: long_period}
            result := indicators.awesome_oscillator(data, awesome_config)
            println('Awesome Oscillator: ${result}')
        }
        19 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0}, indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0}, indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0}, indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0}, indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0}, indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0}, indicators.OHLCV{open: 23.01, high: 23.36, low: 22.91, close: 23.01, volume: 0.0},
                indicators.OHLCV{open: 22.81, high: 23.13, low: 22.65, close: 22.81, volume: 0.0}, indicators.OHLCV{open: 23.36, high: 23.43, low: 22.81, close: 23.36, volume: 0.0},
                indicators.OHLCV{open: 23.31, high: 23.48, low: 23.15, close: 23.31, volume: 0.0}, indicators.OHLCV{open: 23.23, high: 23.43, low: 23.05, close: 23.23, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.28, low: 22.88, close: 23.11, volume: 0.0}, indicators.OHLCV{open: 23.01, high: 23.18, low: 22.85, close: 23.01, volume: 0.0},
                indicators.OHLCV{open: 23.28, high: 23.33, low: 22.93, close: 23.28, volume: 0.0}, indicators.OHLCV{open: 23.13, high: 23.23, low: 22.98, close: 23.13, volume: 0.0},
                indicators.OHLCV{open: 23.08, high: 23.16, low: 22.83, close: 23.08, volume: 0.0}, indicators.OHLCV{open: 22.81, high: 23.06, low: 22.75, close: 22.81, volume: 0.0},
                indicators.OHLCV{open: 22.56, high: 22.86, low: 22.43, close: 22.56, volume: 0.0}, indicators.OHLCV{open: 22.31, high: 22.58, low: 22.24, close: 22.31, volume: 0.0},
                indicators.OHLCV{open: 22.58, high: 22.68, low: 22.27, close: 22.58, volume: 0.0}, indicators.OHLCV{open: 22.28, high: 22.51, low: 22.15, close: 22.28, volume: 0.0},
            ]
            period1 := 7
            period2 := 14
            period3 := 28
            ultimate_config := indicators.UltimateOscillatorConfig{period1: period1, period2: period2, period3: period3}
            result := indicators.ultimate_oscillator(data, ultimate_config)
            println('Ultimate Oscillator: ${result}')
        }
        20 {
            data := [
                indicators.OHLCV{open: 22.27, high: 22.27, low: 22.27, close: 22.27, volume: 0.0},
                indicators.OHLCV{open: 22.19, high: 22.19, low: 22.19, close: 22.19, volume: 0.0},
                indicators.OHLCV{open: 22.08, high: 22.08, low: 22.08, close: 22.08, volume: 0.0},
                indicators.OHLCV{open: 22.17, high: 22.17, low: 22.17, close: 22.17, volume: 0.0},
                indicators.OHLCV{open: 22.18, high: 22.18, low: 22.18, close: 22.18, volume: 0.0},
                indicators.OHLCV{open: 22.13, high: 22.13, low: 22.13, close: 22.13, volume: 0.0},
                indicators.OHLCV{open: 22.23, high: 22.23, low: 22.23, close: 22.23, volume: 0.0},
                indicators.OHLCV{open: 22.43, high: 22.43, low: 22.43, close: 22.43, volume: 0.0},
                indicators.OHLCV{open: 22.24, high: 22.24, low: 22.24, close: 22.24, volume: 0.0},
                indicators.OHLCV{open: 22.29, high: 22.29, low: 22.29, close: 22.29, volume: 0.0},
                indicators.OHLCV{open: 22.15, high: 22.15, low: 22.15, close: 22.15, volume: 0.0},
                indicators.OHLCV{open: 22.39, high: 22.39, low: 22.39, close: 22.39, volume: 0.0},
                indicators.OHLCV{open: 22.38, high: 22.38, low: 22.38, close: 22.38, volume: 0.0},
                indicators.OHLCV{open: 22.61, high: 22.61, low: 22.61, close: 22.61, volume: 0.0},
                indicators.OHLCV{open: 23.36, high: 23.36, low: 23.36, close: 23.36, volume: 0.0},
                indicators.OHLCV{open: 24.05, high: 24.05, low: 24.05, close: 24.05, volume: 0.0},
                indicators.OHLCV{open: 23.75, high: 23.75, low: 23.75, close: 23.75, volume: 0.0},
                indicators.OHLCV{open: 23.83, high: 23.83, low: 23.83, close: 23.83, volume: 0.0},
                indicators.OHLCV{open: 23.95, high: 23.95, low: 23.95, close: 23.95, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.63, low: 23.63, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.82, high: 23.82, low: 23.82, close: 23.82, volume: 0.0},
                indicators.OHLCV{open: 23.87, high: 23.87, low: 23.87, close: 23.87, volume: 0.0},
                indicators.OHLCV{open: 23.65, high: 23.65, low: 23.65, close: 23.65, volume: 0.0},
                indicators.OHLCV{open: 23.19, high: 23.19, low: 23.19, close: 23.19, volume: 0.0},
                indicators.OHLCV{open: 23.10, high: 23.10, low: 23.10, close: 23.10, volume: 0.0},
                indicators.OHLCV{open: 23.33, high: 23.33, low: 23.33, close: 23.33, volume: 0.0},
                indicators.OHLCV{open: 22.68, high: 22.68, low: 22.68, close: 22.68, volume: 0.0},
                indicators.OHLCV{open: 23.10, high: 23.10, low: 23.10, close: 23.10, volume: 0.0},
                indicators.OHLCV{open: 22.40, high: 22.40, low: 22.40, close: 22.40, volume: 0.0},
                indicators.OHLCV{open: 22.17, high: 22.17, low: 22.17, close: 22.17, volume: 0.0},
            ]
            period := 15
            trix_config := indicators.TRIXConfig{period: period}
            result := indicators.trix(data, trix_config)
            println('TRIX: ${result}')
        }
        21 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0}, indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0}, indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0}, indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0}, indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0}, indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0}, indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0}, indicators.OHLCV{open: 23.01, high: 23.36, low: 22.91, close: 23.01, volume: 0.0},
                indicators.OHLCV{open: 22.81, high: 23.13, low: 22.65, close: 22.81, volume: 0.0}, indicators.OHLCV{open: 23.36, high: 23.43, low: 22.81, close: 23.36, volume: 0.0},
                indicators.OHLCV{open: 23.31, high: 23.48, low: 23.15, close: 23.31, volume: 0.0}, indicators.OHLCV{open: 23.23, high: 23.43, low: 23.05, close: 23.23, volume: 0.0},
            ]
            period := 20
            donchian_config := indicators.DonchianConfig{period: period}
            upper, middle, lower := indicators.donchian_channels(data, donchian_config)
            println('Upper Donchian Channel: ${upper}')
            println('Middle Donchian Channel: ${middle}')
            println('Lower Donchian Channel: ${lower}')
        }
        22 {
            data := [
                indicators.OHLCV{open: 1.0, high: 1.0, low: 1.0, close: 1.0, volume: 0.0},
                indicators.OHLCV{open: 1.0, high: 2.0, low: 1.0, close: 2.0, volume: 0.0},
                indicators.OHLCV{open: 2.0, high: 3.0, low: 2.0, close: 3.0, volume: 0.0},
                indicators.OHLCV{open: 3.0, high: 4.0, low: 3.0, close: 4.0, volume: 0.0},
                indicators.OHLCV{open: 4.0, high: 5.0, low: 4.0, close: 5.0, volume: 0.0},
                indicators.OHLCV{open: 5.0, high: 6.0, low: 5.0, close: 6.0, volume: 0.0},
                indicators.OHLCV{open: 6.0, high: 7.0, low: 6.0, close: 7.0, volume: 0.0},
                indicators.OHLCV{open: 7.0, high: 8.0, low: 7.0, close: 8.0, volume: 0.0},
                indicators.OHLCV{open: 8.0, high: 9.0, low: 8.0, close: 9.0, volume: 0.0},
                indicators.OHLCV{open: 9.0, high: 10.0, low: 9.0, close: 10.0, volume: 0.0},
            ]
            period := 5
            wilders_config := indicators.WildersConfig{period: period}
            result := indicators.wilders_smoothing(data, wilders_config)
            println('Wilder\'s Smoothing: ${result}')
        }
        23 {
            data := [
                indicators.OHLCV{open: 1.0, high: 1.0, low: 1.0, close: 1.0, volume: 0.0},
                indicators.OHLCV{open: 1.0, high: 2.0, low: 1.0, close: 2.0, volume: 0.0},
                indicators.OHLCV{open: 2.0, high: 3.0, low: 2.0, close: 3.0, volume: 0.0},
                indicators.OHLCV{open: 3.0, high: 4.0, low: 3.0, close: 4.0, volume: 0.0},
                indicators.OHLCV{open: 4.0, high: 5.0, low: 4.0, close: 5.0, volume: 0.0},
                indicators.OHLCV{open: 5.0, high: 6.0, low: 5.0, close: 6.0, volume: 0.0},
                indicators.OHLCV{open: 6.0, high: 7.0, low: 6.0, close: 7.0, volume: 0.0},
                indicators.OHLCV{open: 7.0, high: 8.0, low: 7.0, close: 8.0, volume: 0.0},
                indicators.OHLCV{open: 8.0, high: 9.0, low: 8.0, close: 9.0, volume: 0.0},
                indicators.OHLCV{open: 9.0, high: 10.0, low: 9.0, close: 10.0, volume: 0.0},
                indicators.OHLCV{open: 10.0, high: 11.0, low: 10.0, close: 11.0, volume: 0.0},
                indicators.OHLCV{open: 11.0, high: 12.0, low: 11.0, close: 12.0, volume: 0.0},
                indicators.OHLCV{open: 12.0, high: 13.0, low: 12.0, close: 13.0, volume: 0.0},
                indicators.OHLCV{open: 13.0, high: 14.0, low: 13.0, close: 14.0, volume: 0.0},
                indicators.OHLCV{open: 14.0, high: 15.0, low: 14.0, close: 15.0, volume: 0.0},
            ]
            period := 5
            roc_config := indicators.ROCConfig{period: period}
            result := indicators.rate_of_change(data, roc_config)
            println('Rate of Change: ${result}')
        }
        24 {
            data := [
                indicators.OHLCV{high: 46.38, low: 46.00, close: 46.28, volume: 10000},
                indicators.OHLCV{high: 46.63, low: 46.22, close: 46.53, volume: 12000},
                indicators.OHLCV{high: 46.52, low: 46.13, close: 46.22, volume: 11000},
                indicators.OHLCV{high: 46.42, low: 45.83, close: 46.15, volume: 13000},
                indicators.OHLCV{high: 46.42, low: 46.00, close: 46.35, volume: 9000},
                indicators.OHLCV{high: 46.83, low: 46.35, close: 46.75, volume: 15000},
                indicators.OHLCV{high: 47.00, low: 46.50, close: 46.90, volume: 14000},
                indicators.OHLCV{high: 46.80, low: 46.40, close: 46.50, volume: 16000},
                indicators.OHLCV{high: 46.50, low: 45.90, close: 46.10, volume: 17000},
                indicators.OHLCV{high: 46.25, low: 45.75, close: 46.15, volume: 18000},
                indicators.OHLCV{high: 46.35, low: 46.00, close: 46.25, volume: 10000},
                indicators.OHLCV{high: 46.85, low: 46.28, close: 46.78, volume: 20000},
                indicators.OHLCV{high: 46.75, low: 46.30, close: 46.55, volume: 19000},
                indicators.OHLCV{high: 46.55, low: 46.05, close: 46.20, volume: 22000},
                indicators.OHLCV{high: 46.25, low: 45.50, close: 45.60, volume: 25000},
            ]
            period := 14
            mfi_config := indicators.MFIConfig{period: period}
            result := indicators.money_flow_index(data, mfi_config)
            println('Money Flow Index: ${result}')
        }
        25 {
            data := [
                indicators.OHLCV{open: 44.34, high: 44.34, low: 44.34, close: 44.34, volume: 0.0},
                indicators.OHLCV{open: 44.09, high: 44.09, low: 44.09, close: 44.09, volume: 0.0},
                indicators.OHLCV{open: 44.15, high: 44.15, low: 44.15, close: 44.15, volume: 0.0},
                indicators.OHLCV{open: 43.61, high: 43.61, low: 43.61, close: 43.61, volume: 0.0},
                indicators.OHLCV{open: 44.33, high: 44.33, low: 44.33, close: 44.33, volume: 0.0},
                indicators.OHLCV{open: 44.83, high: 44.83, low: 44.83, close: 44.83, volume: 0.0},
                indicators.OHLCV{open: 45.10, high: 45.10, low: 45.10, close: 45.10, volume: 0.0},
                indicators.OHLCV{open: 45.42, high: 45.42, low: 45.42, close: 45.42, volume: 0.0},
                indicators.OHLCV{open: 45.84, high: 45.84, low: 45.84, close: 45.84, volume: 0.0},
                indicators.OHLCV{open: 46.08, high: 46.08, low: 46.08, close: 46.08, volume: 0.0},
                indicators.OHLCV{open: 45.89, high: 45.89, low: 45.89, close: 45.89, volume: 0.0},
                indicators.OHLCV{open: 46.03, high: 46.03, low: 46.03, close: 46.03, volume: 0.0},
                indicators.OHLCV{open: 45.61, high: 45.61, low: 45.61, close: 45.61, volume: 0.0},
                indicators.OHLCV{open: 46.28, high: 46.28, low: 46.28, close: 46.28, volume: 0.0},
                indicators.OHLCV{open: 46.28, high: 46.28, low: 46.28, close: 46.28, volume: 0.0},
                indicators.OHLCV{open: 46.00, high: 46.00, low: 46.00, close: 46.00, volume: 0.0},
                indicators.OHLCV{open: 46.03, high: 46.03, low: 46.03, close: 46.03, volume: 0.0},
                indicators.OHLCV{open: 46.08, high: 46.08, low: 46.08, close: 46.08, volume: 0.0},
                indicators.OHLCV{open: 46.03, high: 46.03, low: 46.03, close: 46.03, volume: 0.0},
                indicators.OHLCV{open: 46.03, high: 46.03, low: 46.03, close: 46.03, volume: 0.0},
                indicators.OHLCV{open: 45.75, high: 45.75, low: 45.75, close: 45.75, volume: 0.0},
                indicators.OHLCV{open: 45.78, high: 45.78, low: 45.78, close: 45.78, volume: 0.0},
                indicators.OHLCV{open: 45.91, high: 45.91, low: 45.91, close: 45.91, volume: 0.0},
                indicators.OHLCV{open: 45.91, high: 45.91, low: 45.91, close: 45.91, volume: 0.0},
                indicators.OHLCV{open: 45.91, high: 45.91, low: 45.91, close: 45.91, volume: 0.0},
                indicators.OHLCV{open: 45.81, high: 45.81, low: 45.81, close: 45.81, volume: 0.0},
                indicators.OHLCV{open: 45.63, high: 45.63, low: 45.63, close: 45.63, volume: 0.0},
                indicators.OHLCV{open: 45.63, high: 45.63, low: 45.63, close: 45.63, volume: 0.0},
                indicators.OHLCV{open: 45.63, high: 45.63, low: 45.63, close: 45.63, volume: 0.0},
                indicators.OHLCV{open: 45.63, high: 45.63, low: 45.63, close: 45.63, volume: 0.0},
            ]
            period := 14
            k_period := 14
            d_period := 3
            stoch_rsi_config := indicators.StochasticRSIConfig{rsi_period: period, k_period: k_period, d_period: d_period}
            k, d := indicators.stochastic_rsi(data, stoch_rsi_config)
            println('Stochastic RSI %K: ${k}')
            println('Stochastic RSI %D: ${d}')
        }
        26 {
            data := [
                indicators.OHLCV{open: 110.7, high: 110.7, low: 110.7, close: 110.7, volume: 0.0},
                indicators.OHLCV{open: 110.8, high: 110.8, low: 110.8, close: 110.8, volume: 0.0},
                indicators.OHLCV{open: 111.0, high: 111.0, low: 111.0, close: 111.0, volume: 0.0},
                indicators.OHLCV{open: 111.2, high: 111.2, low: 111.2, close: 111.2, volume: 0.0},
                indicators.OHLCV{open: 111.4, high: 111.4, low: 111.4, close: 111.4, volume: 0.0},
                indicators.OHLCV{open: 111.6, high: 111.6, low: 111.6, close: 111.6, volume: 0.0},
                indicators.OHLCV{open: 111.8, high: 111.8, low: 111.8, close: 111.8, volume: 0.0},
                indicators.OHLCV{open: 112.0, high: 112.0, low: 112.0, close: 112.0, volume: 0.0},
                indicators.OHLCV{open: 112.2, high: 112.2, low: 112.2, close: 112.2, volume: 0.0},
                indicators.OHLCV{open: 112.4, high: 112.4, low: 112.4, close: 112.4, volume: 0.0},
                indicators.OHLCV{open: 112.6, high: 112.6, low: 112.6, close: 112.6, volume: 0.0},
                indicators.OHLCV{open: 112.8, high: 112.8, low: 112.8, close: 112.8, volume: 0.0},
                indicators.OHLCV{open: 113.0, high: 113.0, low: 113.0, close: 113.0, volume: 0.0},
                indicators.OHLCV{open: 113.2, high: 113.2, low: 113.2, close: 113.2, volume: 0.0},
                indicators.OHLCV{open: 113.4, high: 113.4, low: 113.4, close: 113.4, volume: 0.0},
                indicators.OHLCV{open: 113.6, high: 113.6, low: 113.6, close: 113.6, volume: 0.0},
                indicators.OHLCV{open: 113.8, high: 113.8, low: 113.8, close: 113.8, volume: 0.0},
                indicators.OHLCV{open: 114.0, high: 114.0, low: 114.0, close: 114.0, volume: 0.0},
                indicators.OHLCV{open: 114.2, high: 114.2, low: 114.2, close: 114.2, volume: 0.0},
                indicators.OHLCV{open: 114.4, high: 114.4, low: 114.4, close: 114.4, volume: 0.0},
                indicators.OHLCV{open: 114.6, high: 114.6, low: 114.6, close: 114.6, volume: 0.0},
                indicators.OHLCV{open: 114.8, high: 114.8, low: 114.8, close: 114.8, volume: 0.0},
                indicators.OHLCV{open: 115.0, high: 115.0, low: 115.0, close: 115.0, volume: 0.0},
                indicators.OHLCV{open: 115.2, high: 115.2, low: 115.2, close: 115.2, volume: 0.0},
                indicators.OHLCV{open: 115.4, high: 115.4, low: 115.4, close: 115.4, volume: 0.0},
                indicators.OHLCV{open: 115.6, high: 115.6, low: 115.6, close: 115.6, volume: 0.0},
                indicators.OHLCV{open: 115.8, high: 115.8, low: 115.8, close: 115.8, volume: 0.0},
                indicators.OHLCV{open: 116.0, high: 116.0, low: 116.0, close: 116.0, volume: 0.0},
                indicators.OHLCV{open: 116.2, high: 116.2, low: 116.2, close: 116.2, volume: 0.0},
                indicators.OHLCV{open: 116.4, high: 116.4, low: 116.4, close: 116.4, volume: 0.0},
                indicators.OHLCV{open: 116.6, high: 116.6, low: 116.6, close: 116.6, volume: 0.0},
                indicators.OHLCV{open: 116.8, high: 116.8, low: 116.8, close: 116.8, volume: 0.0},
                indicators.OHLCV{open: 117.0, high: 117.0, low: 117.0, close: 117.0, volume: 0.0},
                indicators.OHLCV{open: 117.2, high: 117.2, low: 117.2, close: 117.2, volume: 0.0},
                indicators.OHLCV{open: 117.4, high: 117.4, low: 117.4, close: 117.4, volume: 0.0},
                indicators.OHLCV{open: 117.6, high: 117.6, low: 117.6, close: 117.6, volume: 0.0},
                indicators.OHLCV{open: 117.8, high: 117.8, low: 117.8, close: 117.8, volume: 0.0},
                indicators.OHLCV{open: 118.0, high: 118.0, low: 118.0, close: 118.0, volume: 0.0},
                indicators.OHLCV{open: 118.2, high: 118.2, low: 118.2, close: 118.2, volume: 0.0},
                indicators.OHLCV{open: 118.4, high: 118.4, low: 118.4, close: 118.4, volume: 0.0},
                indicators.OHLCV{open: 118.6, high: 118.6, low: 118.6, close: 118.6, volume: 0.0},
                indicators.OHLCV{open: 118.8, high: 118.8, low: 118.8, close: 118.8, volume: 0.0},
                indicators.OHLCV{open: 119.0, high: 119.0, low: 119.0, close: 119.0, volume: 0.0},
                indicators.OHLCV{open: 119.2, high: 119.2, low: 119.2, close: 119.2, volume: 0.0},
                indicators.OHLCV{open: 119.4, high: 119.4, low: 119.4, close: 119.4, volume: 0.0},
                indicators.OHLCV{open: 119.6, high: 119.6, low: 119.6, close: 119.6, volume: 0.0},
                indicators.OHLCV{open: 119.8, high: 119.8, low: 119.8, close: 119.8, volume: 0.0},
                indicators.OHLCV{open: 120.0, high: 120.0, low: 120.0, close: 120.0, volume: 0.0},
                indicators.OHLCV{open: 120.2, high: 120.2, low: 120.2, close: 120.2, volume: 0.0},
                indicators.OHLCV{open: 120.4, high: 120.4, low: 120.4, close: 120.4, volume: 0.0},
            ]
            roc1 := 10
            roc2 := 15
            roc3 := 20
            roc4 := 30
            sma1 := 10
            sma2 := 10
            sma3 := 10
            sma4 := 15
            signal_period := 9
            kst_config := indicators.KSTConfig{roc1_period: roc1, roc2_period: roc2, roc3_period: roc3, roc4_period: roc4, sma1_period: sma1, sma2_period: sma2, sma3_period: sma3, sma4_period: sma4, signal_period: signal_period}
            kst, signal := indicators.know_sure_thing(data, kst_config)
            println('KST: ${kst}')
            println('Signal Line: ${signal}')
        }
        27 {
            data := [
                indicators.OHLCV{open: 110.7, high: 110.7, low: 110.7, close: 110.7, volume: 0.0},
                indicators.OHLCV{open: 110.8, high: 110.8, low: 110.8, close: 110.8, volume: 0.0},
                indicators.OHLCV{open: 111.0, high: 111.0, low: 111.0, close: 111.0, volume: 0.0},
                indicators.OHLCV{open: 111.2, high: 111.2, low: 111.2, close: 111.2, volume: 0.0},
                indicators.OHLCV{open: 111.4, high: 111.4, low: 111.4, close: 111.4, volume: 0.0},
                indicators.OHLCV{open: 111.6, high: 111.6, low: 111.6, close: 111.6, volume: 0.0},
                indicators.OHLCV{open: 111.8, high: 111.8, low: 111.8, close: 111.8, volume: 0.0},
                indicators.OHLCV{open: 112.0, high: 112.0, low: 112.0, close: 112.0, volume: 0.0},
                indicators.OHLCV{open: 112.2, high: 112.2, low: 112.2, close: 112.2, volume: 0.0},
                indicators.OHLCV{open: 112.4, high: 112.4, low: 112.4, close: 112.4, volume: 0.0},
                indicators.OHLCV{open: 112.6, high: 112.6, low: 112.6, close: 112.6, volume: 0.0},
                indicators.OHLCV{open: 112.8, high: 112.8, low: 112.8, close: 112.8, volume: 0.0},
                indicators.OHLCV{open: 113.0, high: 113.0, low: 113.0, close: 113.0, volume: 0.0},
                indicators.OHLCV{open: 113.2, high: 113.2, low: 113.2, close: 113.2, volume: 0.0},
                indicators.OHLCV{open: 113.4, high: 113.4, low: 113.4, close: 113.4, volume: 0.0},
                indicators.OHLCV{open: 113.6, high: 113.6, low: 113.6, close: 113.6, volume: 0.0},
                indicators.OHLCV{open: 113.8, high: 113.8, low: 113.8, close: 113.8, volume: 0.0},
                indicators.OHLCV{open: 114.0, high: 114.0, low: 114.0, close: 114.0, volume: 0.0},
                indicators.OHLCV{open: 114.2, high: 114.2, low: 114.2, close: 114.2, volume: 0.0},
                indicators.OHLCV{open: 114.4, high: 114.4, low: 114.4, close: 114.4, volume: 0.0},
                indicators.OHLCV{open: 114.6, high: 114.6, low: 114.6, close: 114.6, volume: 0.0},
                indicators.OHLCV{open: 114.8, high: 114.8, low: 114.8, close: 114.8, volume: 0.0},
                indicators.OHLCV{open: 115.0, high: 115.0, low: 115.0, close: 115.0, volume: 0.0},
                indicators.OHLCV{open: 115.2, high: 115.2, low: 115.2, close: 115.2, volume: 0.0},
                indicators.OHLCV{open: 115.4, high: 115.4, low: 115.4, close: 115.4, volume: 0.0},
                indicators.OHLCV{open: 115.6, high: 115.6, low: 115.6, close: 115.6, volume: 0.0},
                indicators.OHLCV{open: 115.8, high: 115.8, low: 115.8, close: 115.8, volume: 0.0},
                indicators.OHLCV{open: 116.0, high: 116.0, low: 116.0, close: 116.0, volume: 0.0},
                indicators.OHLCV{open: 116.2, high: 116.2, low: 116.2, close: 116.2, volume: 0.0},
                indicators.OHLCV{open: 116.4, high: 116.4, low: 116.4, close: 116.4, volume: 0.0},
                indicators.OHLCV{open: 116.6, high: 116.6, low: 116.6, close: 116.6, volume: 0.0},
                indicators.OHLCV{open: 116.8, high: 116.8, low: 116.8, close: 116.8, volume: 0.0},
                indicators.OHLCV{open: 117.0, high: 117.0, low: 117.0, close: 117.0, volume: 0.0},
                indicators.OHLCV{open: 117.2, high: 117.2, low: 117.2, close: 117.2, volume: 0.0},
                indicators.OHLCV{open: 117.4, high: 117.4, low: 117.4, close: 117.4, volume: 0.0},
                indicators.OHLCV{open: 117.6, high: 117.6, low: 117.6, close: 117.6, volume: 0.0},
                indicators.OHLCV{open: 117.8, high: 117.8, low: 117.8, close: 117.8, volume: 0.0},
                indicators.OHLCV{open: 118.0, high: 118.0, low: 118.0, close: 118.0, volume: 0.0},
                indicators.OHLCV{open: 118.2, high: 118.2, low: 118.2, close: 118.2, volume: 0.0},
                indicators.OHLCV{open: 118.4, high: 118.4, low: 118.4, close: 118.4, volume: 0.0},
                indicators.OHLCV{open: 118.6, high: 118.6, low: 118.6, close: 118.6, volume: 0.0},
                indicators.OHLCV{open: 118.8, high: 118.8, low: 118.8, close: 118.8, volume: 0.0},
                indicators.OHLCV{open: 119.0, high: 119.0, low: 119.0, close: 119.0, volume: 0.0},
                indicators.OHLCV{open: 119.2, high: 119.2, low: 119.2, close: 119.2, volume: 0.0},
                indicators.OHLCV{open: 119.4, high: 119.4, low: 119.4, close: 119.4, volume: 0.0},
                indicators.OHLCV{open: 119.6, high: 119.6, low: 119.6, close: 119.6, volume: 0.0},
                indicators.OHLCV{open: 119.8, high: 119.8, low: 119.8, close: 119.8, volume: 0.0},
                indicators.OHLCV{open: 120.0, high: 120.0, low: 120.0, close: 120.0, volume: 0.0},
                indicators.OHLCV{open: 120.2, high: 120.2, low: 120.2, close: 120.2, volume: 0.0},
                indicators.OHLCV{open: 120.4, high: 120.4, low: 120.4, close: 120.4, volume: 0.0},
            ]
            roc1_period := 14
            roc2_period := 11
            wma_period := 10
            coppock_config := indicators.CoppockConfig{roc1_period: roc1_period, roc2_period: roc2_period, wma_period: wma_period}
            result := indicators.coppock_curve(data, coppock_config)
            println('Coppock Curve: ${result}')
        }
        28 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.VortexConfig{period: 14}
            if validated_config := config.validate() {
                vortex_plus, vortex_minus := indicators.vortex_indicator(data, validated_config)
                println('Vortex Configuration: ${config}')
                println('Vortex +VI: ${vortex_plus}')
                println('Vortex -VI: ${vortex_minus}')
            } else {
                println('Invalid Vortex configuration: ${config}')
            }
        }
        29 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.HMAConfig{period: 10}
            if validated_config := config.validate() {
                result := indicators.hull_moving_average(data, validated_config)
                println('Hull Moving Average Configuration: ${config}')
                println('Hull Moving Average Result: ${result}')
            } else {
                println('Invalid Hull Moving Average configuration: ${config}')
            }
        }
        30 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.LinearRegressionConfig{period: 10}
            if validated_config := config.validate() {
                result := indicators.linear_regression(data, validated_config)
                println('Linear Regression Configuration: ${config}')
                println('Linear Regression Line: ${result.line}')
                println('Linear Regression Slope: ${result.slope}')
            } else {
                println('Invalid Linear Regression configuration: ${config}')
            }
        }
        31 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 1000},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 1200},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 1500},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 2000},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 1800},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 1700},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 1600},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 1900},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 1400},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 2100},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 2200},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 2500},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 2300},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 3000},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 2800},
            ]
            
            // Using configuration struct
            config := indicators.VWMAConfig{period: 10}
            if validated_config := config.validate() {
                result := indicators.volume_weighted_moving_average(data, validated_config)
                println('Volume Weighted Moving Average Configuration: ${config}')
                println('Volume Weighted Moving Average Result: ${result}')
            } else {
                println('Invalid Volume Weighted Moving Average configuration: ${config}')
            }
        }
        32 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.DEMAConfig{period: 10}
            if validated_config := config.validate() {
                result := indicators.double_exponential_moving_average(data, validated_config)
                println('Double Exponential Moving Average Configuration: ${config}')
                println('Double Exponential Moving Average Result: ${result}')
            } else {
                println('Invalid Double Exponential Moving Average configuration: ${config}')
            }
        }
        33 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.TEMAConfig{period: 10}
            if validated_config := config.validate() {
                result := indicators.triple_exponential_moving_average(data, validated_config)
                println('Triple Exponential Moving Average Configuration: ${config}')
                println('Triple Exponential Moving Average Result: ${result}')
            } else {
                println('Invalid Triple Exponential Moving Average configuration: ${config}')
            }
        }
        34 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.AMAConfig{fast_period: 2, slow_period: 30}
            if validated_config := config.validate() {
                result := indicators.adaptive_moving_average(data, validated_config)
                println('Adaptive Moving Average Configuration: ${config}')
                println('Adaptive Moving Average Result: ${result}')
            } else {
                println('Invalid Adaptive Moving Average configuration: ${config}')
            }
        }
        35 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.ALMAConfig{period: 10, sigma: 6.0, offset: 0.85}
            if validated_config := config.validate() {
                result := indicators.arnaud_legoux_moving_average(data, validated_config)
                println('Arnaud Legoux Moving Average Configuration: ${config}')
                println('Arnaud Legoux Moving Average Result: ${result}')
            } else {
                println('Invalid Arnaud Legoux Moving Average configuration: ${config}')
            }
        }
        36 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.MomentumConfig{period: 10}
            if validated_config := config.validate() {
                result := indicators.momentum(data, validated_config)
                println('Momentum Configuration: ${config}')
                println('Momentum Result: ${result}')
            } else {
                println('Invalid Momentum configuration: ${config}')
            }
        }
        37 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.PROCConfig{period: 10}
            if validated_config := config.validate() {
                result := indicators.price_rate_of_change(data, validated_config)
                println('Price Rate of Change Configuration: ${config}')
                println('Price Rate of Change Result: ${result}')
            } else {
                println('Invalid Price Rate of Change configuration: ${config}')
            }
        }
        38 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.DPOConfig{period: 20}
            if validated_config := config.validate() {
                result := indicators.detrended_price_oscillator(data, validated_config)
                println('Detrended Price Oscillator Configuration: ${config}')
                println('Detrended Price Oscillator Result: ${result}')
            } else {
                println('Invalid Detrended Price Oscillator configuration: ${config}')
            }
        }
        39 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.PPOConfig{fast_period: 12, slow_period: 26, signal_period: 9}
            if validated_config := config.validate() {
                result := indicators.percentage_price_oscillator(data, validated_config)
                println('Percentage Price Oscillator Configuration: ${config}')
                println('PPO Line: ${result.ppo_line}')
                println('Signal Line: ${result.signal_line}')
                println('Histogram: ${result.histogram}')
            } else {
                println('Invalid Percentage Price Oscillator configuration: ${config}')
            }
        }
        40 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.CMOConfig{period: 14}
            if validated_config := config.validate() {
                result := indicators.chande_momentum_oscillator(data, validated_config)
                println('Chande Momentum Oscillator Configuration: ${config}')
                println('Chande Momentum Oscillator Result: ${result}')
            } else {
                println('Invalid Chande Momentum Oscillator configuration: ${config}')
            }
        }
        41 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.FisherConfig{period: 10}
            if validated_config := config.validate() {
                result := indicators.fisher_transform(data, validated_config)
                println('Fisher Transform Configuration: ${config}')
                println('Fisher Line: ${result.fisher}')
                println('Trigger Line: ${result.trigger}')
            } else {
                println('Invalid Fisher Transform configuration: ${config}')
            }
        }
        42 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 1000},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 1200},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 1500},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 2000},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 1800},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 1700},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 1600},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 1900},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 1400},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 2100},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 2200},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 2500},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 2300},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 3000},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 2800},
            ]
            
            // Using configuration struct
            config := indicators.EOMConfig{period: 14}
            if validated_config := config.validate() {
                result := indicators.ease_of_movement(data, validated_config)
                println('Ease of Movement Configuration: ${config}')
                println('Ease of Movement Result: ${result}')
            } else {
                println('Invalid Ease of Movement configuration: ${config}')
            }
        }
        43 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.StdDevConfig{period: 20}
            if validated_config := config.validate() {
                result := indicators.standard_deviation(data, validated_config)
                println('Standard Deviation Configuration: ${config}')
                println('Standard Deviation Result: ${result}')
            } else {
                println('Invalid Standard Deviation configuration: ${config}')
            }
        }
        44 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.HistoricalVolatilityConfig{period: 20}
            if validated_config := config.validate() {
                result := indicators.historical_volatility(data, validated_config)
                println('Historical Volatility Configuration: ${config}')
                println('Historical Volatility Result: ${result}')
            } else {
                println('Invalid Historical Volatility configuration: ${config}')
            }
        }
        45 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.ChaikinVolatilityConfig{period: 10}
            if validated_config := config.validate() {
                result := indicators.chaikin_volatility(data, validated_config)
                println('Chaikin Volatility Configuration: ${config}')
                println('Chaikin Volatility Result: ${result}')
            } else {
                println('Invalid Chaikin Volatility configuration: ${config}')
            }
        }
        46 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.UlcerIndexConfig{period: 14}
            if validated_config := config.validate() {
                result := indicators.ulcer_index(data, validated_config)
                println('Ulcer Index Configuration: ${config}')
                println('Ulcer Index Result: ${result}')
            } else {
                println('Invalid Ulcer Index configuration: ${config}')
            }
        }
        47 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.GatorConfig{jaw_period: 13, teeth_period: 8, lips_period: 5}
            if validated_config := config.validate() {
                result := indicators.gator_oscillator(data, validated_config)
                println('Gator Oscillator Configuration: ${config}')
                println('Upper Gator: ${result.upper_jaw}')
                println('Lower Gator: ${result.lower_jaw}')
            } else {
                println('Invalid Gator Oscillator configuration: ${config}')
            }
        }
        48 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 1000},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 1200},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 1500},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 2000},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 1800},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 1700},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 1600},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 1900},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 1400},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 2100},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 2200},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 2500},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 2300},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 3000},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 2800},
            ]
            
            // Using configuration struct
            config := indicators.VolumeROCConfig{period: 25}
            if validated_config := config.validate() {
                result := indicators.volume_rate_of_change(data, validated_config)
                println('Volume Rate of Change Configuration: ${config}')
                println('Volume Rate of Change Result: ${result}')
            } else {
                println('Invalid Volume Rate of Change configuration: ${config}')
            }
        }
        49 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 1000},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 1200},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 1500},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 2000},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 1800},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 1700},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 1600},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 1900},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 1400},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 2100},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 2200},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 2500},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 2300},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 3000},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 2800},
            ]
            
            // Using configuration struct
            config := indicators.VPTConfig{period: 14}
            if validated_config := config.validate() {
                result := indicators.volume_price_trend(data, validated_config)
                println('Volume Price Trend Configuration: ${config}')
                println('Volume Price Trend Result: ${result}')
            } else {
                println('Invalid Volume Price Trend configuration: ${config}')
            }
        }
        50 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 1000},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 1200},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 1500},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 2000},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 1800},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 1700},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 1600},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 1900},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 1400},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 2100},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 2200},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 2500},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 2300},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 3000},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 2800},
            ]
            
            // Using configuration struct
            config := indicators.NVIConfig{period: 255}
            if validated_config := config.validate() {
                result := indicators.negative_volume_index(data, validated_config)
                println('Negative Volume Index Configuration: ${config}')
                println('Negative Volume Index Result: ${result}')
            } else {
                println('Invalid Negative Volume Index configuration: ${config}')
            }
        }
        51 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 1000},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 1200},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 1500},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 2000},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 1800},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 1700},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 1600},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 1900},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 1400},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 2100},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 2200},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 2500},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 2300},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 3000},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 2800},
            ]
            
            // Using configuration struct
            config := indicators.PVIConfig{period: 255}
            if validated_config := config.validate() {
                result := indicators.positive_volume_index(data, validated_config)
                println('Positive Volume Index Configuration: ${config}')
                println('Positive Volume Index Result: ${result}')
            } else {
                println('Invalid Positive Volume Index configuration: ${config}')
            }
        }
        52 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 1000},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 1200},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 1500},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 2000},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 1800},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 1700},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 1600},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 1900},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 1400},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 2100},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 2200},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 2500},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 2300},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 3000},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 2800},
            ]
            
            // Using configuration struct
            config := indicators.MFVConfig{period: 14}
            if validated_config := config.validate() {
                result := indicators.money_flow_volume(data, validated_config)
                println('Money Flow Volume Configuration: ${config}')
                println('Money Flow Volume Result: ${result}')
            } else {
                println('Invalid Money Flow Volume configuration: ${config}')
            }
        }
        53 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 1000},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 1200},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 1500},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 2000},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 1800},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 1700},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 1600},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 1900},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 1400},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 2100},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 2200},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 2500},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 2300},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 3000},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 2800},
            ]
            
            // Using configuration struct
            config := indicators.EnhancedVWAPConfig{period: 20}
            if validated_config := config.validate() {
                result := indicators.enhanced_vwap(data, validated_config)
                println('Enhanced VWAP Configuration: ${config}')
                println('Enhanced VWAP Result: ${result}')
            } else {
                println('Invalid Enhanced VWAP configuration: ${config}')
            }
        }
        54 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.PivotPointsConfig{}
            if validated_config := config.validate() {
                result := indicators.pivot_points(data, validated_config)
                println('Pivot Points Configuration: ${config}')
                println('Pivot: ${result.pivot_point}')
                println('R1: ${result.resistance1}, R2: ${result.resistance2}, R3: ${result.resistance3}')
                println('S1: ${result.support1}, S2: ${result.support2}, S3: ${result.support3}')
            } else {
                println('Invalid Pivot Points configuration: ${config}')
            }
        }
        55 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.FibonacciConfig{lookback_period: 20}
            if validated_config := config.validate() {
                result := indicators.fibonacci_retracements(data, validated_config)
                println('Fibonacci Retracements Configuration: ${config}')
                println('Fibonacci Retracements: ${result}')
            } else {
                println('Invalid Fibonacci Retracements configuration: ${config}')
            }
        }
        56 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.PriceChannelsConfig{period: 20}
            if validated_config := config.validate() {
                result := indicators.price_channels(data, validated_config)
                println('Price Channels Configuration: ${config}')
                println('Upper Channel: ${result.upper_channel}')
                println('Lower Channel: ${result.lower_channel}')
            } else {
                println('Invalid Price Channels configuration: ${config}')
            }
        }
        57 {
            data := [
                indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 0.0},
                indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 0.0},
                indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 0.0},
                indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 0.0},
                indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 0.0},
                indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 0.0},
                indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 0.0},
                indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 0.0},
                indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 0.0},
                indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 0.0},
                indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 0.0},
                indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 0.0},
                indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 0.0},
            ]
            
            // Using configuration struct
            config := indicators.AndrewsPitchforkConfig{}
            if validated_config := config.validate() {
                result := indicators.andrews_pitchfork(data, validated_config)
                println('Andrews Pitchfork Configuration: ${config}')
                println('Upper Line: ${result.upper_line}')
                println('Median Line: ${result.median_line}')
                println('Lower Line: ${result.lower_line}')
            } else {
                println('Invalid Andrews Pitchfork configuration: ${config}')
            }
        }
        else {
            println('Invalid choice.')
        }
    }
}