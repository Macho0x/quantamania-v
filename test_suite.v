import indicators

fn main() {
    println('V Language Technical Indicators Test Suite')
    println('=========================================')
    println('')

    mut test_count := 0
    mut passed_count := 0

    // Test data sets
    test_data_1 := [
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

    test_data_2 := [
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

    test_data_3 := [
        indicators.OHLCV{open: 23.66, high: 23.98, low: 23.52, close: 23.66, volume: 1000.0},
        indicators.OHLCV{open: 23.61, high: 23.71, low: 23.33, close: 23.61, volume: 1200.0},
        indicators.OHLCV{open: 23.85, high: 23.91, low: 23.21, close: 23.85, volume: 1100.0},
        indicators.OHLCV{open: 24.62, high: 24.83, low: 23.87, close: 24.62, volume: 1300.0},
        indicators.OHLCV{open: 24.25, high: 24.73, low: 24.22, close: 24.25, volume: 1400.0},
        indicators.OHLCV{open: 24.18, high: 24.48, low: 23.82, close: 24.18, volume: 1500.0},
        indicators.OHLCV{open: 24.11, high: 24.28, low: 23.64, close: 24.11, volume: 1600.0},
        indicators.OHLCV{open: 24.35, high: 24.41, low: 23.88, close: 24.35, volume: 1700.0},
        indicators.OHLCV{open: 24.11, high: 24.36, low: 24.01, close: 24.11, volume: 1800.0},
        indicators.OHLCV{open: 23.76, high: 24.38, low: 23.73, close: 23.76, volume: 1900.0},
        indicators.OHLCV{open: 24.03, high: 24.08, low: 23.58, close: 24.03, volume: 2000.0},
        indicators.OHLCV{open: 23.63, high: 23.91, low: 23.43, close: 23.63, volume: 2100.0},
        indicators.OHLCV{open: 23.73, high: 23.83, low: 23.21, close: 23.73, volume: 2200.0},
        indicators.OHLCV{open: 23.06, high: 23.51, low: 22.92, close: 23.06, volume: 2300.0},
        indicators.OHLCV{open: 23.11, high: 23.31, low: 22.68, close: 23.11, volume: 2400.0},
        indicators.OHLCV{open: 23.01, high: 23.36, low: 22.91, close: 23.01, volume: 2500.0},
        indicators.OHLCV{open: 22.81, high: 23.13, low: 22.65, close: 22.81, volume: 2600.0},
        indicators.OHLCV{open: 23.36, high: 23.43, low: 22.81, close: 23.36, volume: 2700.0},
        indicators.OHLCV{open: 23.31, high: 23.48, low: 23.15, close: 23.31, volume: 2800.0},
        indicators.OHLCV{open: 23.23, high: 23.43, low: 23.05, close: 23.23, volume: 2900.0},
        indicators.OHLCV{open: 23.11, high: 23.28, low: 22.88, close: 23.11, volume: 3000.0},
        indicators.OHLCV{open: 23.01, high: 23.18, low: 22.85, close: 23.01, volume: 3100.0},
        indicators.OHLCV{open: 23.28, high: 23.33, low: 22.93, close: 23.28, volume: 3200.0},
        indicators.OHLCV{open: 23.13, high: 23.23, low: 22.98, close: 23.13, volume: 3300.0},
        indicators.OHLCV{open: 23.08, high: 23.16, low: 22.83, close: 23.08, volume: 3400.0},
        indicators.OHLCV{open: 22.81, high: 23.06, low: 22.75, close: 22.81, volume: 3500.0},
        indicators.OHLCV{open: 22.56, high: 22.86, low: 22.43, close: 22.56, volume: 3600.0},
        indicators.OHLCV{open: 22.31, high: 22.58, low: 22.24, close: 22.31, volume: 3700.0},
        indicators.OHLCV{open: 22.58, high: 22.68, low: 22.27, close: 22.58, volume: 3800.0},
        indicators.OHLCV{open: 22.28, high: 22.51, low: 22.15, close: 22.28, volume: 3900.0},
        indicators.OHLCV{open: 22.45, high: 22.65, low: 22.35, close: 22.45, volume: 4000.0},
        indicators.OHLCV{open: 22.60, high: 22.80, low: 22.50, close: 22.60, volume: 4100.0},
        indicators.OHLCV{open: 22.75, high: 22.95, low: 22.65, close: 22.75, volume: 4200.0},
        indicators.OHLCV{open: 22.90, high: 23.10, low: 22.80, close: 22.90, volume: 4300.0},
        indicators.OHLCV{open: 23.05, high: 23.25, low: 22.95, close: 23.05, volume: 4400.0},
        indicators.OHLCV{open: 23.20, high: 23.40, low: 23.10, close: 23.20, volume: 4500.0},
        indicators.OHLCV{open: 23.35, high: 23.55, low: 23.25, close: 23.35, volume: 4600.0},
        indicators.OHLCV{open: 23.50, high: 23.70, low: 23.40, close: 23.50, volume: 4700.0},
        indicators.OHLCV{open: 23.65, high: 23.85, low: 23.55, close: 23.65, volume: 4800.0},
        indicators.OHLCV{open: 23.80, high: 24.00, low: 23.70, close: 23.80, volume: 4900.0},
        indicators.OHLCV{open: 23.95, high: 24.15, low: 23.85, close: 23.95, volume: 5000.0},
        indicators.OHLCV{open: 24.10, high: 24.30, low: 24.00, close: 24.10, volume: 5100.0},
        indicators.OHLCV{open: 24.25, high: 24.45, low: 24.15, close: 24.25, volume: 5200.0},
        indicators.OHLCV{open: 24.40, high: 24.60, low: 24.30, close: 24.40, volume: 5300.0},
        indicators.OHLCV{open: 24.55, high: 24.75, low: 24.45, close: 24.55, volume: 5400.0},
        indicators.OHLCV{open: 24.70, high: 24.90, low: 24.60, close: 24.70, volume: 5500.0},
        indicators.OHLCV{open: 24.85, high: 25.05, low: 24.75, close: 24.85, volume: 5600.0},
        indicators.OHLCV{open: 25.00, high: 25.20, low: 24.90, close: 25.00, volume: 5700.0},
        indicators.OHLCV{open: 25.15, high: 25.35, low: 25.05, close: 25.15, volume: 5800.0},
        indicators.OHLCV{open: 25.30, high: 25.50, low: 25.20, close: 25.30, volume: 5900.0},
        indicators.OHLCV{open: 25.45, high: 25.65, low: 25.35, close: 25.45, volume: 6000.0},
        indicators.OHLCV{open: 25.60, high: 25.80, low: 25.50, close: 25.60, volume: 6100.0},
        indicators.OHLCV{open: 25.75, high: 25.95, low: 25.65, close: 25.75, volume: 6200.0},
        indicators.OHLCV{open: 25.90, high: 26.10, low: 25.80, close: 25.90, volume: 6300.0},
        indicators.OHLCV{open: 26.05, high: 26.25, low: 25.95, close: 26.05, volume: 6400.0},
        indicators.OHLCV{open: 26.20, high: 26.40, low: 26.10, close: 26.20, volume: 6500.0},
        indicators.OHLCV{open: 26.35, high: 26.55, low: 26.25, close: 26.35, volume: 6600.0},
        indicators.OHLCV{open: 26.50, high: 26.70, low: 26.40, close: 26.50, volume: 6700.0},
        indicators.OHLCV{open: 26.65, high: 26.85, low: 26.55, close: 26.65, volume: 6800.0},
        indicators.OHLCV{open: 26.80, high: 27.00, low: 26.70, close: 26.80, volume: 6900.0},
        indicators.OHLCV{open: 26.95, high: 27.15, low: 26.85, close: 26.95, volume: 7000.0},
        indicators.OHLCV{open: 27.10, high: 27.30, low: 27.00, close: 27.10, volume: 7100.0},
        indicators.OHLCV{open: 27.25, high: 27.45, low: 27.15, close: 27.25, volume: 7200.0},
        indicators.OHLCV{open: 27.40, high: 27.60, low: 27.30, close: 27.40, volume: 7300.0},
        indicators.OHLCV{open: 27.55, high: 27.75, low: 27.45, close: 27.55, volume: 7400.0},
        indicators.OHLCV{open: 27.70, high: 27.90, low: 27.60, close: 27.70, volume: 7500.0},
        indicators.OHLCV{open: 27.85, high: 28.05, low: 27.75, close: 27.85, volume: 7600.0},
        indicators.OHLCV{open: 28.00, high: 28.20, low: 27.90, close: 28.00, volume: 7700.0},
        indicators.OHLCV{open: 28.15, high: 28.35, low: 28.05, close: 28.15, volume: 7800.0},
        indicators.OHLCV{open: 28.30, high: 28.50, low: 28.20, close: 28.30, volume: 7900.0},
        indicators.OHLCV{open: 28.45, high: 28.65, low: 28.35, close: 28.45, volume: 8000.0},
        indicators.OHLCV{open: 28.60, high: 28.80, low: 28.50, close: 28.60, volume: 8100.0},
        indicators.OHLCV{open: 28.75, high: 28.95, low: 28.65, close: 28.75, volume: 8200.0},
        indicators.OHLCV{open: 28.90, high: 29.10, low: 28.80, close: 28.90, volume: 8300.0},
        indicators.OHLCV{open: 29.05, high: 29.25, low: 28.95, close: 29.05, volume: 8400.0},
        indicators.OHLCV{open: 29.20, high: 29.40, low: 29.10, close: 29.20, volume: 8500.0},
        indicators.OHLCV{open: 29.35, high: 29.55, low: 29.25, close: 29.35, volume: 8600.0},
        indicators.OHLCV{open: 29.50, high: 29.70, low: 29.40, close: 29.50, volume: 8700.0},
        indicators.OHLCV{open: 29.65, high: 29.85, low: 29.55, close: 29.65, volume: 8800.0},
        indicators.OHLCV{open: 29.80, high: 30.00, low: 29.70, close: 29.80, volume: 8900.0},
        indicators.OHLCV{open: 29.95, high: 30.15, low: 29.85, close: 29.95, volume: 9000.0},
        indicators.OHLCV{open: 30.10, high: 30.30, low: 30.00, close: 30.10, volume: 9100.0},
        indicators.OHLCV{open: 30.25, high: 30.45, low: 30.15, close: 30.25, volume: 9200.0},
        indicators.OHLCV{open: 30.40, high: 30.60, low: 30.30, close: 30.40, volume: 9300.0},
        indicators.OHLCV{open: 30.55, high: 30.75, low: 30.45, close: 30.55, volume: 9400.0},
        indicators.OHLCV{open: 30.70, high: 30.90, low: 30.60, close: 30.70, volume: 9500.0},
        indicators.OHLCV{open: 30.85, high: 31.05, low: 30.75, close: 30.85, volume: 9600.0},
        indicators.OHLCV{open: 31.00, high: 31.20, low: 30.90, close: 31.00, volume: 9700.0},
        indicators.OHLCV{open: 31.15, high: 31.35, low: 31.05, close: 31.15, volume: 9800.0},
        indicators.OHLCV{open: 31.30, high: 31.50, low: 31.20, close: 31.30, volume: 9900.0},
        indicators.OHLCV{open: 31.45, high: 31.65, low: 31.35, close: 31.45, volume: 10000.0},
    ]

    // Test 1: Simple Moving Average (SMA)
    test_count++
    println('Test ${test_count}: Simple Moving Average (SMA)')
    sma_config := indicators.SMAConfig{period: 5}
    validated_config := sma_config.validate() or {
        println('✗ FAILED - Invalid SMA configuration: ${sma_config}')
        println('')
        return
    }
    sma_result := indicators.sma(test_data_1, validated_config)
    if sma_result.len > 0 {
        println('✓ PASSED - SMA calculated successfully with config: ${sma_config}')
        passed_count++
    } else {
        println('✗ FAILED - SMA calculation failed')
    }
    println('')

    // Test 2: Exponential Moving Average (EMA)
    test_count++
    println('Test ${test_count}: Exponential Moving Average (EMA)')
    ema_config := indicators.EMAConfig{period: 5}
    validated_ema_config := ema_config.validate() or {
        println('✗ FAILED - Invalid EMA configuration: ${ema_config}')
        println('')
        return
    }
    ema_result := indicators.ema(test_data_1, validated_ema_config)
    if ema_result.len > 0 {
        println('✓ PASSED - EMA calculated successfully with config: ${ema_config}')
        passed_count++
    } else {
        println('✗ FAILED - EMA calculation failed')
    }
    println('')

    // Test 3: Bollinger Bands
    test_count++
    println('Test ${test_count}: Bollinger Bands')
    bollinger_config := indicators.BollingerConfig{period: 5, num_std_dev: 2.0}
    validated_bollinger_config := bollinger_config.validate() or {
        println('✗ FAILED - Invalid Bollinger configuration: ${bollinger_config}')
        println('')
        return
    }
    upper, middle, lower := indicators.bollinger_bands(test_data_1, validated_bollinger_config)
    if upper.len > 0 && middle.len > 0 && lower.len > 0 {
        println('✓ PASSED - Bollinger Bands calculated successfully with config: ${bollinger_config}')
        passed_count++
    } else {
        println('✗ FAILED - Bollinger Bands calculation failed')
    }
    println('')

    // Test 4: Relative Strength Index (RSI)
    test_count++
    println('Test ${test_count}: Relative Strength Index (RSI)')
    rsi_config := indicators.RSIConfig{period: 14}
    validated_rsi_config := rsi_config.validate() or {
        println('✗ FAILED - Invalid RSI configuration: ${rsi_config}')
        println('')
        return
    }
    rsi_result := indicators.rsi(test_data_2, validated_rsi_config)
    if rsi_result.len > 0 {
    	println('✓ PASSED - RSI calculated successfully with config: ${rsi_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - RSI calculation failed')
    }
    println('')

    // Test 5: Average Directional Index (ADX)
    test_count++
    println('Test ${test_count}: Average Directional Index (ADX)')
    adx_config := indicators.ADXConfig{period: 14}
    validated_adx_config := adx_config.validate() or {
        println('✗ FAILED - Invalid ADX configuration: ${adx_config}')
        println('')
        return
    }
    adx_line, plus_di, minus_di := indicators.adx(test_data_3, validated_adx_config)
    if adx_line.len > 0 && plus_di.len > 0 && minus_di.len > 0 {
    	println('✓ PASSED - ADX calculated successfully with config: ${adx_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - ADX calculation failed')
    }
    println('')

    // Test 6: Moving Average Convergence Divergence (MACD)
    test_count++
    println('Test ${test_count}: Moving Average Convergence Divergence (MACD)')
    macd_config := indicators.MACDConfig{short_period: 12, long_period: 26, signal_period: 9}
    validated_macd_config := macd_config.validate() or {
    	println('✗ FAILED - Invalid MACD configuration: ${macd_config}')
    	println('')
    	return
    }
    macd_line, signal_line, histogram := indicators.macd(test_data_3, validated_macd_config)
    if macd_line.len > 0 && signal_line.len > 0 && histogram.len > 0 {
    	println('✓ PASSED - MACD calculated successfully with config: ${macd_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - MACD calculation failed')
    }
    println('')

    // Test 7: Parabolic SAR
    test_count++
    println('Test ${test_count}: Parabolic SAR')
    sar_config := indicators.ParabolicSARConfig{acceleration: 0.02, max_acceleration: 0.2}
    validated_sar_config := sar_config.validate() or {
    	println('✗ FAILED - Invalid Parabolic SAR configuration: ${sar_config}')
    	println('')
    	return
    }
    sar_result := indicators.parabolic_sar(test_data_3, validated_sar_config)
    if sar_result.len > 0 {
    	println('✓ PASSED - Parabolic SAR calculated successfully with config: ${sar_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Parabolic SAR calculation failed')
    }
    println('')

    // Test 8: Ichimoku Cloud
    test_count++
    println('Test ${test_count}: Ichimoku Cloud')
    ichimoku_config := indicators.IchimokuConfig{tenkan_period: 9, kijun_period: 26, senkou_b_period: 52}
    validated_ichimoku_config := ichimoku_config.validate() or {
    	println('✗ FAILED - Invalid Ichimoku configuration: ${ichimoku_config}')
    	println('')
    	return
    }
    tenkan, kijun, senkou_a, senkou_b, chikou := indicators.ichimoku_cloud(test_data_3, validated_ichimoku_config)
    if tenkan.len > 0 && kijun.len > 0 && senkou_a.len > 0 && senkou_b.len > 0 && chikou.len > 0 {
    	println('✓ PASSED - Ichimoku Cloud calculated successfully with config: ${ichimoku_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Ichimoku Cloud calculation failed')
    }
    println('')

    // Test 9: Stochastic Oscillator
    test_count++
    println('Test ${test_count}: Stochastic Oscillator')
    stochastic_config := indicators.StochasticConfig{k_period: 14, d_period: 3}
    validated_stochastic_config := stochastic_config.validate() or {
    	println('✗ FAILED - Invalid Stochastic configuration: ${stochastic_config}')
    	println('')
    	return
    }
    k_line, d_line := indicators.stochastic_oscillator(test_data_3, validated_stochastic_config)
    if k_line.len > 0 && d_line.len > 0 {
    	println('✓ PASSED - Stochastic Oscillator calculated successfully with config: ${stochastic_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Stochastic Oscillator calculation failed')
    }
    println('')

    // Test 10: Williams %R
    test_count++
    println('Test ${test_count}: Williams %R')
    williams_config := indicators.WilliamsRConfig{period: 14}
    validated_williams_config := williams_config.validate() or {
    	println('✗ FAILED - Invalid Williams %R configuration: ${williams_config}')
    	println('')
    	return
    }
    williams_result := indicators.williams_percent_r(test_data_3, validated_williams_config)
    if williams_result.len > 0 {
    	println('✓ PASSED - Williams %R calculated successfully with config: ${williams_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Williams %R calculation failed')
    }
    println('')

    // Test 11: Commodity Channel Index (CCI)
    test_count++
    println('Test ${test_count}: Commodity Channel Index (CCI)')
    cci_config := indicators.CCIConfig{period: 20}
    validated_cci_config := cci_config.validate() or {
    	println('✗ FAILED - Invalid CCI configuration: ${cci_config}')
    	println('')
    	return
    }
    cci_result := indicators.cci(test_data_3, validated_cci_config)
    if cci_result.len > 0 {
    	println('✓ PASSED - CCI calculated successfully with config: ${cci_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - CCI calculation failed')
    }
    println('')

    // Test 12: On-Balance Volume (OBV)
    test_count++
    println('Test ${test_count}: On-Balance Volume (OBV)')
    obv_result := indicators.on_balance_volume(test_data_3)
    if obv_result.len > 0 {
        println('✓ PASSED - OBV calculated successfully')
        passed_count++
    } else {
        println('✗ FAILED - OBV calculation failed')
    }
    println('')

    // Test 13: Accumulation/Distribution Line
    test_count++
    println('Test ${test_count}: Accumulation/Distribution Line')
    ad_line_result := indicators.accumulation_distribution_line(test_data_3)
    if ad_line_result.len > 0 {
        println('✓ PASSED - A/D Line calculated successfully')
        passed_count++
    } else {
        println('✗ FAILED - A/D Line calculation failed')
    }
    println('')

    // Test 14: Chaikin Money Flow
    test_count++
    println('Test ${test_count}: Chaikin Money Flow')
    cmf_config := indicators.CMFConfig{period: 20}
    validated_cmf_config := cmf_config.validate() or {
    	println('✗ FAILED - Invalid CMF configuration: ${cmf_config}')
    	println('')
    	return
    }
    cmf_result := indicators.chaikin_money_flow(test_data_3, validated_cmf_config)
    if cmf_result.len > 0 {
    	println('✓ PASSED - Chaikin Money Flow calculated successfully with config: ${cmf_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Chaikin Money Flow calculation failed')
    }
    println('')

    // Test 15: Average True Range (ATR)
    test_count++
    println('Test ${test_count}: Average True Range (ATR)')
    atr_config := indicators.ATRConfig{period: 14}
    validated_atr_config := atr_config.validate() or {
    	println('✗ FAILED - Invalid ATR configuration: ${atr_config}')
    	println('')
    	return
    }
    atr_result := indicators.average_true_range(test_data_3, validated_atr_config)
    if atr_result.len > 0 {
    	println('✓ PASSED - ATR calculated successfully with config: ${atr_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - ATR calculation failed')
    }
    println('')

    // Test 16: Keltner Channels
    test_count++
    println('Test ${test_count}: Keltner Channels')
    keltner_config := indicators.KeltnerConfig{period: 20, atr_multiplier: 2.0}
    validated_keltner_config := keltner_config.validate() or {
    	println('✗ FAILED - Invalid Keltner configuration: ${keltner_config}')
    	println('')
    	return
    }
    keltner_upper, keltner_middle, keltner_lower := indicators.keltner_channels(test_data_3, validated_keltner_config)
    if keltner_upper.len > 0 && keltner_middle.len > 0 && keltner_lower.len > 0 {
    	println('✓ PASSED - Keltner Channels calculated successfully with config: ${keltner_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Keltner Channels calculation failed')
    }
    println('')

    // Test 17: Volume Weighted Average Price (VWAP)
    test_count++
    println('Test ${test_count}: Volume Weighted Average Price (VWAP)')
    vwap_result := indicators.vwap(test_data_3)
    if vwap_result.len > 0 {
        println('✓ PASSED - VWAP calculated successfully')
        passed_count++
    } else {
        println('✗ FAILED - VWAP calculation failed')
    }
    println('')

    // Test 18: Awesome Oscillator
    test_count++
    println('Test ${test_count}: Awesome Oscillator')
    awesome_config := indicators.AwesomeOscillatorConfig{short_period: 5, long_period: 34}
    validated_awesome_config := awesome_config.validate() or {
    	println('✗ FAILED - Invalid Awesome Oscillator configuration: ${awesome_config}')
    	println('')
    	return
    }
    awesome_result := indicators.awesome_oscillator(test_data_3, validated_awesome_config)
    if awesome_result.len > 0 {
    	println('✓ PASSED - Awesome Oscillator calculated successfully with config: ${awesome_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Awesome Oscillator calculation failed')
    }
    println('')

    // Test 19: Ultimate Oscillator
    test_count++
    println('Test ${test_count}: Ultimate Oscillator')
    ultimate_config := indicators.UltimateOscillatorConfig{period1: 7, period2: 14, period3: 28}
    validated_ultimate_config := ultimate_config.validate() or {
    	println('✗ FAILED - Invalid Ultimate Oscillator configuration: ${ultimate_config}')
    	println('')
    	return
    }
    ultimate_result := indicators.ultimate_oscillator(test_data_3, validated_ultimate_config)
    if ultimate_result.len > 0 {
    	println('✓ PASSED - Ultimate Oscillator calculated successfully with config: ${ultimate_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Ultimate Oscillator calculation failed')
    }
    println('')

    // Test 20: TRIX
    test_count++
    println('Test ${test_count}: TRIX')
    trix_config := indicators.TRIXConfig{period: 15}
    validated_trix_config := trix_config.validate() or {
    	println('✗ FAILED - Invalid TRIX configuration: ${trix_config}')
    	println('')
    	return
    }
    trix_result := indicators.trix(test_data_3, validated_trix_config)
    if trix_result.len > 0 {
    	println('✓ PASSED - TRIX calculated successfully with config: ${trix_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - TRIX calculation failed')
    }
    println('')

    // Test 21: Donchian Channels
    test_count++
    println('Test ${test_count}: Donchian Channels')
    donchian_config := indicators.DonchianConfig{period: 20}
    validated_donchian_config := donchian_config.validate() or {
    	println('✗ FAILED - Invalid Donchian configuration: ${donchian_config}')
    	println('')
    	return
    }
    donchian_upper, donchian_middle, donchian_lower := indicators.donchian_channels(test_data_3, validated_donchian_config)
    if donchian_upper.len > 0 && donchian_middle.len > 0 && donchian_lower.len > 0 {
    	println('✓ PASSED - Donchian Channels calculated successfully with config: ${donchian_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Donchian Channels calculation failed')
    }
    println('')

    // Test 22: Wilder's Smoothing
    test_count++
    println('Test ${test_count}: Wilder\'s Smoothing')
    wilders_config := indicators.WildersConfig{period: 14}
    validated_wilders_config := wilders_config.validate() or {
    	println('✗ FAILED - Invalid Wilder\'s configuration: ${wilders_config}')
    	println('')
    	return
    }
    wilders_result := indicators.wilders_smoothing(test_data_3, validated_wilders_config)
    if wilders_result.len > 0 {
    	println('✓ PASSED - Wilder\'s Smoothing calculated successfully with config: ${wilders_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Wilder\'s Smoothing calculation failed')
    }
    println('')

    // Test 23: Rate of Change (ROC)
    test_count++
    println('Test ${test_count}: Rate of Change (ROC)')
    roc_config := indicators.ROCConfig{period: 10}
    validated_roc_config := roc_config.validate() or {
    	println('✗ FAILED - Invalid ROC configuration: ${roc_config}')
    	println('')
    	return
    }
    roc_result := indicators.rate_of_change(test_data_3, validated_roc_config)
    if roc_result.len > 0 {
    	println('✓ PASSED - ROC calculated successfully with config: ${roc_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - ROC calculation failed')
    }
    println('')

    // Test 24: Money Flow Index
    test_count++
    println('Test ${test_count}: Money Flow Index')
    mfi_config := indicators.MFIConfig{period: 14}
    validated_mfi_config := mfi_config.validate() or {
    	println('✗ FAILED - Invalid MFI configuration: ${mfi_config}')
    	println('')
    	return
    }
    mfi_result := indicators.money_flow_index(test_data_3, validated_mfi_config)
    if mfi_result.len > 0 {
    	println('✓ PASSED - MFI calculated successfully with config: ${mfi_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - MFI calculation failed')
    }
    println('')

    // Test 25: Stochastic RSI
    test_count++
    println('Test ${test_count}: Stochastic RSI')
    stoch_rsi_config := indicators.StochasticRSIConfig{rsi_period: 14, k_period: 14, d_period: 3}
    validated_stoch_rsi_config := stoch_rsi_config.validate() or {
    	println('✗ FAILED - Invalid Stochastic RSI configuration: ${stoch_rsi_config}')
    	println('')
    	return
    }
    stoch_rsi_k, stoch_rsi_d := indicators.stochastic_rsi(test_data_3, validated_stoch_rsi_config)
    if stoch_rsi_k.len > 0 && stoch_rsi_d.len > 0 {
    	println('✓ PASSED - Stochastic RSI calculated successfully with config: ${stoch_rsi_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Stochastic RSI calculation failed')
    }
    println('')

    // Test 26: Know Sure Thing (KST)
    test_count++
    println('Test ${test_count}: Know Sure Thing (KST)')
    kst_config := indicators.KSTConfig{
        roc1_period: 10, roc2_period: 15, roc3_period: 20, roc4_period: 30,
        sma1_period: 10, sma2_period: 10, sma3_period: 10, sma4_period: 15,
        signal_period: 9
    }
    validated_kst_config := kst_config.validate() or {
    	println('✗ FAILED - Invalid KST configuration: ${kst_config}')
    	println('')
    	return
    }
    kst_line, kst_signal := indicators.know_sure_thing(test_data_3, validated_kst_config)
    if kst_line.len > 0 && kst_signal.len > 0 {
    	println('✓ PASSED - KST calculated successfully with config: ${kst_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - KST calculation failed')
    }
    println('')

    // Test 27: Coppock Curve
    test_count++
    println('Test ${test_count}: Coppock Curve')
    coppock_config := indicators.CoppockConfig{roc1_period: 14, roc2_period: 11, wma_period: 10}
    validated_coppock_config := coppock_config.validate() or {
    	println('✗ FAILED - Invalid Coppock configuration: ${coppock_config}')
    	println('')
    	return
    }
    coppock_result := indicators.coppock_curve(test_data_3, validated_coppock_config)
    if coppock_result.len > 0 {
    	println('✓ PASSED - Coppock Curve calculated successfully with config: ${coppock_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Coppock Curve calculation failed')
    }
    println('')

    // Test 28: Vortex Indicator
    test_count++
    println('Test ${test_count}: Vortex Indicator')
    vortex_config := indicators.VortexConfig{period: 14}
    validated_vortex_config := vortex_config.validate() or {
    	println('✗ FAILED - Invalid Vortex configuration: ${vortex_config}')
    	println('')
    	return
    }
    plus_vi, minus_vi := indicators.vortex_indicator(test_data_3, validated_vortex_config)
    if plus_vi.len > 0 && minus_vi.len > 0 {
    	println('✓ PASSED - Vortex Indicator calculated successfully with config: ${vortex_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Vortex Indicator calculation failed')
    }
    println('')

    // Test 29: Hull Moving Average (HMA)
    test_count++
    println('Test ${test_count}: Hull Moving Average (HMA)')
    hma_config := indicators.HMAConfig{period: 20}
    validated_hma_config := hma_config.validate() or {
    	println('✗ FAILED - Invalid HMA configuration: ${hma_config}')
    	println('')
    	return
    }
    hma_result := indicators.hull_moving_average(test_data_3, validated_hma_config)
    if hma_result.len > 0 {
    	println('✓ PASSED - HMA calculated successfully with config: ${hma_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - HMA calculation failed')
    }
    println('')

    // Test 30: Linear Regression
    test_count++
    println('Test ${test_count}: Linear Regression')
    linear_reg_config := indicators.LinearRegressionConfig{period: 20}
    validated_linear_reg_config := linear_reg_config.validate() or {
    	println('✗ FAILED - Invalid Linear Regression configuration: ${linear_reg_config}')
    	println('')
    	return
    }
    linear_result := indicators.linear_regression(test_data_3, validated_linear_reg_config)
    if linear_result.line.len > 0 && linear_result.slope.len > 0 {
    	println('✓ PASSED - Linear Regression calculated successfully with config: ${linear_reg_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Linear Regression calculation failed')
    }
    println('')

    // Test 31: Volume Weighted Moving Average (VWMA)
    test_count++
    println('Test ${test_count}: Volume Weighted Moving Average (VWMA)')
    vwma_config := indicators.VWMAConfig{period: 20}
    validated_vwma_config := vwma_config.validate() or {
    	println('✗ FAILED - Invalid VWMA configuration: ${vwma_config}')
    	println('')
    	return
    }
    vwma_result := indicators.volume_weighted_moving_average(test_data_3, validated_vwma_config)
    if vwma_result.len > 0 {
    	println('✓ PASSED - VWMA calculated successfully with config: ${vwma_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - VWMA calculation failed')
    }
    println('')

    // Test 32: Double Exponential Moving Average (DEMA)
    test_count++
    println('Test ${test_count}: Double Exponential Moving Average (DEMA)')
    dema_config := indicators.DEMAConfig{period: 20}
    validated_dema_config := dema_config.validate() or {
    	println('✗ FAILED - Invalid DEMA configuration: ${dema_config}')
    	println('')
    	return
    }
    dema_result := indicators.double_exponential_moving_average(test_data_3, validated_dema_config)
    if dema_result.len > 0 {
    	println('✓ PASSED - DEMA calculated successfully with config: ${dema_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - DEMA calculation failed')
    }
    println('')

    // Test 33: Triple Exponential Moving Average (TEMA)
    test_count++
    println('Test ${test_count}: Triple Exponential Moving Average (TEMA)')
    tema_config := indicators.TEMAConfig{period: 20}
    validated_tema_config := tema_config.validate() or {
    	println('✗ FAILED - Invalid TEMA configuration: ${tema_config}')
    	println('')
    	return
    }
    tema_result := indicators.triple_exponential_moving_average(test_data_3, validated_tema_config)
    if tema_result.len > 0 {
    	println('✓ PASSED - TEMA calculated successfully with config: ${tema_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - TEMA calculation failed')
    }
    println('')

    // Test 34: Adaptive Moving Average (AMA)
    test_count++
    println('Test ${test_count}: Adaptive Moving Average (AMA)')
    ama_config := indicators.AMAConfig{fast_period: 2, slow_period: 30}
    validated_ama_config := ama_config.validate() or {
    	println('✗ FAILED - Invalid AMA configuration: ${ama_config}')
    	println('')
    	return
    }
    ama_result := indicators.adaptive_moving_average(test_data_3, validated_ama_config)
    if ama_result.len > 0 {
    	println('✓ PASSED - AMA calculated successfully with config: ${ama_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - AMA calculation failed')
    }
    println('')

    // Test 35: Arnaud Legoux Moving Average (ALMA)
    test_count++
    println('Test ${test_count}: Arnaud Legoux Moving Average (ALMA)')
    alma_config := indicators.ALMAConfig{period: 20, sigma: 6.0, offset: 0.85}
    validated_alma_config := alma_config.validate() or {
    	println('✗ FAILED - Invalid ALMA configuration: ${alma_config}')
    	println('')
    	return
    }
    alma_result := indicators.arnaud_legoux_moving_average(test_data_3, validated_alma_config)
    if alma_result.len > 0 {
    	println('✓ PASSED - ALMA calculated successfully with config: ${alma_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - ALMA calculation failed')
    }
    println('')

    // Test 36: Momentum
    test_count++
    println('Test ${test_count}: Momentum')
    momentum_config := indicators.MomentumConfig{period: 10}
    validated_momentum_config := momentum_config.validate() or {
    	println('✗ FAILED - Invalid Momentum configuration: ${momentum_config}')
    	println('')
    	return
    }
    momentum_result := indicators.momentum(test_data_3, validated_momentum_config)
    if momentum_result.len > 0 {
    	println('✓ PASSED - Momentum calculated successfully with config: ${momentum_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Momentum calculation failed')
    }
    println('')

    // Test 37: Price Rate of Change (PROC)
    test_count++
    println('Test ${test_count}: Price Rate of Change (PROC)')
    proc_config := indicators.PROCConfig{period: 10}
    validated_proc_config := proc_config.validate() or {
    	println('✗ FAILED - Invalid PROC configuration: ${proc_config}')
    	println('')
    	return
    }
    proc_result := indicators.price_rate_of_change(test_data_3, validated_proc_config)
    if proc_result.len > 0 {
    	println('✓ PASSED - PROC calculated successfully with config: ${proc_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - PROC calculation failed')
    }
    println('')

    // Test 38: Detrended Price Oscillator (DPO)
    test_count++
    println('Test ${test_count}: Detrended Price Oscillator (DPO)')
    dpo_config := indicators.DPOConfig{period: 20}
    validated_dpo_config := dpo_config.validate() or {
    	println('✗ FAILED - Invalid DPO configuration: ${dpo_config}')
    	println('')
    	return
    }
    dpo_result := indicators.detrended_price_oscillator(test_data_3, validated_dpo_config)
    if dpo_result.len > 0 {
    	println('✓ PASSED - DPO calculated successfully with config: ${dpo_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - DPO calculation failed')
    }
    println('')

    // Test 39: Percentage Price Oscillator (PPO)
    test_count++
    println('Test ${test_count}: Percentage Price Oscillator (PPO)')
    ppo_config := indicators.PPOConfig{fast_period: 12, slow_period: 26, signal_period: 9}
    validated_ppo_config := ppo_config.validate() or {
    	println('✗ FAILED - Invalid PPO configuration: ${ppo_config}')
    	println('')
    	return
    }
    ppo_result := indicators.percentage_price_oscillator(test_data_3, validated_ppo_config)
    if ppo_result.ppo_line.len > 0 && ppo_result.signal_line.len > 0 && ppo_result.histogram.len > 0 {
    	println('✓ PASSED - PPO calculated successfully with config: ${ppo_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - PPO calculation failed')
    }
    println('')

    // Test 40: Chande Momentum Oscillator (CMO)
    test_count++
    println('Test ${test_count}: Chande Momentum Oscillator (CMO)')
    cmo_config := indicators.CMOConfig{period: 14}
    validated_cmo_config := cmo_config.validate() or {
    	println('✗ FAILED - Invalid CMO configuration: ${cmo_config}')
    	println('')
    	return
    }
    cmo_result := indicators.chande_momentum_oscillator(test_data_3, validated_cmo_config)
    if cmo_result.len > 0 {
    	println('✓ PASSED - CMO calculated successfully with config: ${cmo_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - CMO calculation failed')
    }
    println('')

    // Test 41: Fisher Transform
    test_count++
    println('Test ${test_count}: Fisher Transform')
    fisher_config := indicators.FisherConfig{period: 10}
    validated_fisher_config := fisher_config.validate() or {
    	println('✗ FAILED - Invalid Fisher configuration: ${fisher_config}')
    	println('')
    	return
    }
    fisher_result := indicators.fisher_transform(test_data_3, validated_fisher_config)
    if fisher_result.fisher.len > 0 && fisher_result.trigger.len > 0 {
    	println('✓ PASSED - Fisher Transform calculated successfully with config: ${fisher_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Fisher Transform calculation failed')
    }
    println('')

    // Test 42: Ease of Movement (EOM)
    test_count++
    println('Test ${test_count}: Ease of Movement (EOM)')
    eom_config := indicators.EMVConfig{period: 14}
    validated_eom_config := eom_config.validate() or {
    	println('✗ FAILED - Invalid EOM configuration: ${eom_config}')
    	println('')
    	return
    }
    eom_result := indicators.ease_of_movement(test_data_3, validated_eom_config)
    if eom_result.len > 0 {
        println('✓ PASSED - EOM calculated successfully with config: ${eom_config}')
        passed_count++
    } else {
        println('✗ FAILED - EOM calculation failed')
    }
    println('')

    // Test 43: Standard Deviation
    test_count++
    println('Test ${test_count}: Standard Deviation')
    std_dev_config := indicators.StdDevConfig{period: 20}
    validated_std_dev_config := std_dev_config.validate() or {
    	println('✗ FAILED - Invalid Standard Deviation configuration: ${std_dev_config}')
    	println('')
    	return
    }
    std_dev_result := indicators.standard_deviation(test_data_3, validated_std_dev_config)
    if std_dev_result.len > 0 {
    	println('✓ PASSED - Standard Deviation calculated successfully with config: ${std_dev_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Standard Deviation calculation failed')
    }
    println('')

    // Test 44: Historical Volatility
    test_count++
    println('Test ${test_count}: Historical Volatility')
    hist_vol_config := indicators.HistoricalVolatilityConfig{period: 20}
    validated_hist_vol_config := hist_vol_config.validate() or {
    	println('✗ FAILED - Invalid Historical Volatility configuration: ${hist_vol_config}')
    	println('')
    	return
    }
    hist_vol_result := indicators.historical_volatility(test_data_3, validated_hist_vol_config)
    if hist_vol_result.len > 0 {
    	println('✓ PASSED - Historical Volatility calculated successfully with config: ${hist_vol_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Historical Volatility calculation failed')
    }
    println('')

    // Test 45: Chaikin Volatility
    test_count++
    println('Test ${test_count}: Chaikin Volatility')
    chaikin_vol_config := indicators.ChaikinVolatilityConfig{period: 10}
    validated_chaikin_vol_config := chaikin_vol_config.validate() or {
    	println('✗ FAILED - Invalid Chaikin Volatility configuration: ${chaikin_vol_config}')
    	println('')
    	return
    }
    chaikin_vol_result := indicators.chaikin_volatility(test_data_3, validated_chaikin_vol_config)
    if chaikin_vol_result.len > 0 {
    	println('✓ PASSED - Chaikin Volatility calculated successfully with config: ${chaikin_vol_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Chaikin Volatility calculation failed')
    }
    println('')

    // Test 46: Ulcer Index
    test_count++
    println('Test ${test_count}: Ulcer Index')
    ulcer_config := indicators.UlcerIndexConfig{period: 14}
    validated_ulcer_config := ulcer_config.validate() or {
    	println('✗ FAILED - Invalid Ulcer Index configuration: ${ulcer_config}')
    	println('')
    	return
    }
    ulcer_result := indicators.ulcer_index(test_data_3, validated_ulcer_config)
    if ulcer_result.len > 0 {
    	println('✓ PASSED - Ulcer Index calculated successfully with config: ${ulcer_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Ulcer Index calculation failed')
    }
    println('')

    // Test 47: Gator Oscillator
    test_count++
    println('Test ${test_count}: Gator Oscillator')
    gator_config := indicators.GatorConfig{jaw_period: 13, teeth_period: 8, lips_period: 5}
    validated_gator_config := gator_config.validate() or {
    	println('✗ FAILED - Invalid Gator configuration: ${gator_config}')
    	println('')
    	return
    }
    gator_result := indicators.gator_oscillator(test_data_3, validated_gator_config)
    if gator_result.upper_jaw.len > 0 && gator_result.lower_jaw.len > 0 {
    	println('✓ PASSED - Gator Oscillator calculated successfully with config: ${gator_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Gator Oscillator calculation failed')
    }
    println('')

    // Test 48: Volume Rate of Change (Volume ROC)
    test_count++
    println('Test ${test_count}: Volume Rate of Change (Volume ROC)')
    volume_roc_config := indicators.VolumeROCConfig{period: 25}
    validated_volume_roc_config := volume_roc_config.validate() or {
    	println('✗ FAILED - Invalid Volume ROC configuration: ${volume_roc_config}')
    	println('')
    	return
    }
    volume_roc_result := indicators.volume_rate_of_change(test_data_3, validated_volume_roc_config)
    if volume_roc_result.len > 0 {
    	println('✓ PASSED - Volume ROC calculated successfully with config: ${volume_roc_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Volume ROC calculation failed')
    }
    println('')

    // Test 49: Volume Price Trend (VPT)
    test_count++
    println('Test ${test_count}: Volume Price Trend (VPT)')
    vpt_config := indicators.VPTConfig{period: 14}
    validated_vpt_config := vpt_config.validate() or {
    	println('✗ FAILED - Invalid VPT configuration: ${vpt_config}')
    	println('')
    	return
    }
    vpt_result := indicators.volume_price_trend(test_data_3, validated_vpt_config)
    if vpt_result.len > 0 {
    	println('✓ PASSED - VPT calculated successfully with config: ${vpt_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - VPT calculation failed')
    }
    println('')

    // Test 50: Negative Volume Index (NVI)
    test_count++
    println('Test ${test_count}: Negative Volume Index (NVI)')
    nvi_config := indicators.NVIConfig{period: 20}
    validated_nvi_config := nvi_config.validate() or {
    	println('✗ FAILED - Invalid NVI configuration: ${nvi_config}')
    	println('')
    	return
    }
    nvi_result := indicators.negative_volume_index(test_data_3, validated_nvi_config)
    if nvi_result.len > 0 {
    	println('✓ PASSED - NVI calculated successfully with config: ${nvi_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - NVI calculation failed')
    }
    println('')

    // Test 51: Positive Volume Index (PVI)
    test_count++
    println('Test ${test_count}: Positive Volume Index (PVI)')
    pvi_config := indicators.PVIConfig{period: 20}
    validated_pvi_config := pvi_config.validate() or {
    	println('✗ FAILED - Invalid PVI configuration: ${pvi_config}')
    	println('')
    	return
    }
    pvi_result := indicators.positive_volume_index(test_data_3, validated_pvi_config)
    if pvi_result.len > 0 {
    	println('✓ PASSED - PVI calculated successfully with config: ${pvi_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - PVI calculation failed')
    }
    println('')

    // Test 52: Money Flow Volume (MFV)
    test_count++
    println('Test ${test_count}: Money Flow Volume (MFV)')
    mfv_config := indicators.MFVConfig{period: 14}
    validated_mfv_config := mfv_config.validate() or {
    	println('✗ FAILED - Invalid MFV configuration: ${mfv_config}')
    	println('')
    	return
    }
    mfv_result := indicators.money_flow_volume(test_data_3, validated_mfv_config)
    if mfv_result.len > 0 {
    	println('✓ PASSED - MFV calculated successfully with config: ${mfv_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - MFV calculation failed')
    }
    println('')

    // Test 53: Enhanced VWAP
    test_count++
    println('Test ${test_count}: Enhanced VWAP')
    enhanced_vwap_config := indicators.EnhancedVWAPConfig{period: 20}
    validated_enhanced_vwap_config := enhanced_vwap_config.validate() or {
    	println('✗ FAILED - Invalid Enhanced VWAP configuration: ${enhanced_vwap_config}')
    	println('')
    	return
    }
    enhanced_vwap_result := indicators.enhanced_vwap(test_data_3, validated_enhanced_vwap_config)
    if enhanced_vwap_result.vwap.len > 0 && enhanced_vwap_result.upper_band.len > 0 &&
    	enhanced_vwap_result.lower_band.len > 0 && enhanced_vwap_result.deviation.len > 0 {
    	println('✓ PASSED - Enhanced VWAP calculated successfully with config: ${enhanced_vwap_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Enhanced VWAP calculation failed')
    }
    println('')

    // Test 54: Pivot Points
    test_count++
    println('Test ${test_count}: Pivot Points')
    pivot_config := indicators.PivotPointsConfig{}
    validated_pivot_config := pivot_config.validate() or {
    	println('✗ FAILED - Invalid Pivot Points configuration')
    	println('')
    	return
    }
    pivot_result := indicators.pivot_points(test_data_3, validated_pivot_config)
    if pivot_result.pivot_point.len > 0 && pivot_result.resistance1.len > 0 &&
    	pivot_result.support1.len > 0 {
    	println('✓ PASSED - Pivot Points calculated successfully')
    	passed_count++
    } else {
    	println('✗ FAILED - Pivot Points calculation failed')
    }
    println('')

    // Test 55: Fibonacci Retracements
    test_count++
    println('Test ${test_count}: Fibonacci Retracements')
    fib_config := indicators.FibonacciConfig{lookback_period: 20}
    validated_fib_config := fib_config.validate() or {
    	println('✗ FAILED - Invalid Fibonacci configuration: ${fib_config}')
    	println('')
    	return
    }
    fib_result := indicators.fibonacci_retracements(test_data_3, validated_fib_config)
    if fib_result.level_0_0.len > 0 && fib_result.level_0_618.len > 0 &&
    	fib_result.level_1_0.len > 0 {
    	println('✓ PASSED - Fibonacci Retracements calculated successfully with config: ${fib_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Fibonacci Retracements calculation failed')
    }
    println('')

    // Test 56: Price Channels
    test_count++
    println('Test ${test_count}: Price Channels')
    price_channels_config := indicators.PriceChannelsConfig{period: 20}
    validated_price_channels_config := price_channels_config.validate() or {
    	println('✗ FAILED - Invalid Price Channels configuration: ${price_channels_config}')
    	println('')
    	return
    }
    price_channels_result := indicators.price_channels(test_data_3, validated_price_channels_config)
    if price_channels_result.upper_channel.len > 0 && price_channels_result.lower_channel.len > 0 &&
    	price_channels_result.midline.len > 0 {
    	println('✓ PASSED - Price Channels calculated successfully with config: ${price_channels_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Price Channels calculation failed')
    }
    println('')

    // Test 57: Andrews Pitchfork
    test_count++
    println('Test ${test_count}: Andrews Pitchfork')
    andrews_config := indicators.AndrewsPitchforkConfig{}
    validated_andrews_config := andrews_config.validate() or {
    	println('✗ FAILED - Invalid Andrews Pitchfork configuration')
    	println('')
    	return
    }
    andrews_result := indicators.andrews_pitchfork(test_data_3, validated_andrews_config)
    if andrews_result.median_line.len > 0 && andrews_result.upper_line.len > 0 &&
    	andrews_result.lower_line.len > 0 {
    	println('✓ PASSED - Andrews Pitchfork calculated successfully')
    	passed_count++
    } else {
    	println('✗ FAILED - Andrews Pitchfork calculation failed')
    }
    println('')

    // Test 58: Elder Ray Index
    test_count++
    println('Test ${test_count}: Elder Ray Index')
    elder_ray_config := indicators.ElderRayConfig{period: 13}
    validated_elder_ray_config := elder_ray_config.validate() or {
    	println('✗ FAILED - Invalid Elder Ray Index configuration: ${elder_ray_config}')
    	println('')
    	return
    }
    elder_ray_result := indicators.elder_ray_index(test_data_3, validated_elder_ray_config)
    if elder_ray_result.bull_power.len > 0 && elder_ray_result.bear_power.len > 0 {
    	println('✓ PASSED - Elder Ray Index calculated successfully with config: ${elder_ray_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Elder Ray Index calculation failed')
    }
    println('')

    // Test 59: Force Index
    test_count++
    println('Test ${test_count}: Force Index')
    force_config := indicators.ForceIndexConfig{period: 2}
    validated_force_config := force_config.validate() or {
    	println('✗ FAILED - Invalid Force Index configuration: ${force_config}')
    	println('')
    	return
    }
    force_result := indicators.force_index(test_data_3, validated_force_config)
    if force_result.len > 0 {
        println('✓ PASSED - Force Index calculated successfully with config: ${force_config}')
        passed_count++
    } else {
        println('✗ FAILED - Force Index calculation failed')
    }
    println('')

    // Test 60: True Strength Index (TSI)
    test_count++
    println('Test ${test_count}: True Strength Index (TSI)')
    tsi_config := indicators.TSIConfig{long_period: 25, short_period: 13}
    validated_tsi_config := tsi_config.validate() or {
    	println('✗ FAILED - Invalid True Strength Index configuration: ${tsi_config}')
    	println('')
    	return
    }
    tsi_result := indicators.true_strength_index(test_data_3, validated_tsi_config)
    if tsi_result.len > 0 {
    	println('✓ PASSED - True Strength Index calculated successfully with config: ${tsi_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - True Strength Index calculation failed')
    }
    println('')

    // Test 61: Choppiness Index
    test_count++
    println('Test ${test_count}: Choppiness Index')
    choppiness_config := indicators.ChoppinessConfig{period: 14}
    validated_choppiness_config := choppiness_config.validate() or {
    	println('✗ FAILED - Invalid Choppiness Index configuration: ${choppiness_config}')
    	println('')
    	return
    }
    choppiness_result := indicators.choppiness_index(test_data_3, validated_choppiness_config)
    if choppiness_result.len > 0 {
        println('✓ PASSED - Choppiness Index calculated successfully with config: ${choppiness_config}')
        passed_count++
    } else {
        println('✗ FAILED - Choppiness Index calculation failed')
    }
    println('')

    // Test 62: Volume Profile
    test_count++
    println('Test ${test_count}: Volume Profile')
    volume_profile_config := indicators.VolumeProfileConfig{num_bins: 10}
    validated_volume_profile_config := volume_profile_config.validate() or {
    	println('✗ FAILED - Invalid Volume Profile configuration: ${volume_profile_config}')
    	println('')
    	return
    }
    volume_profile_result := indicators.volume_profile(test_data_3, validated_volume_profile_config)
    if volume_profile_result.point_of_control > 0 {
    	println('✓ PASSED - Volume Profile calculated successfully with config: ${volume_profile_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Volume Profile calculation failed')
    }
    println('')

    // Test 63: Money Flow Oscillator
    test_count++
    println('Test ${test_count}: Money Flow Oscillator')
    mfo_config := indicators.MoneyFlowOscillatorConfig{period: 14}
    validated_mfo_config := mfo_config.validate() or {
    	println('✗ FAILED - Invalid Money Flow Oscillator configuration: ${mfo_config}')
    	println('')
    	return
    }
    mfo_result := indicators.money_flow_oscillator(test_data_3, validated_mfo_config)
    if mfo_result.len > 0 {
    	println('✓ PASSED - Money Flow Oscillator calculated successfully with config: ${mfo_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Money Flow Oscillator calculation failed')
    }
    println('')

    // Test 64: Volume Weighted MACD
    test_count++
    println('Test ${test_count}: Volume Weighted MACD')
    vw_macd_config := indicators.VolumeWeightedMACDConfig{fast_period: 12, slow_period: 26, signal_period: 9}
    validated_vw_macd_config := vw_macd_config.validate() or {
    	println('✗ FAILED - Invalid Volume Weighted MACD configuration: ${vw_macd_config}')
    	println('')
    	return
    }
    vw_macd_result := indicators.volume_weighted_macd(test_data_3, validated_vw_macd_config)
    if vw_macd_result.macd_line.len > 0 && vw_macd_result.signal_line.len > 0 && vw_macd_result.histogram.len > 0 {
    	println('✓ PASSED - Volume Weighted MACD calculated successfully with config: ${vw_macd_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Volume Weighted MACD calculation failed')
    }
    println('')

    // Test 65: Klinger Oscillator
    test_count++
    println('Test ${test_count}: Klinger Oscillator')
    klinger_config := indicators.KlingerConfig{short_period: 34, long_period: 55, signal_period: 13}
    validated_klinger_config := klinger_config.validate() or {
    	println('✗ FAILED - Invalid Klinger Oscillator configuration: ${klinger_config}')
    	println('')
    	return
    }
    klinger_result := indicators.klinger_oscillator(test_data_3, validated_klinger_config)
    if klinger_result.kvo_line.len > 0 && klinger_result.signal_line.len > 0 {
        println('✓ PASSED - Klinger Oscillator calculated successfully with config: ${klinger_config}')
        passed_count++
    } else {
        println('✗ FAILED - Klinger Oscillator calculation failed')
    }
    println('')

    // Test 66: Woodies CCI
    test_count++
    println('Test ${test_count}: Woodies CCI')
    woodies_config := indicators.WoodiesCCIConfig{cci_period: 14, tlb_period: 6}
    validated_woodies_config := woodies_config.validate() or {
    	println('✗ FAILED - Invalid Woodies CCI configuration: ${woodies_config}')
    	println('')
    	return
    }
    cci_line, tlb_line := indicators.woodies_cci(test_data_3, validated_woodies_config)
    if cci_line.len > 0 && tlb_line.len > 0 {
    	println('✓ PASSED - Woodies CCI calculated successfully with config: ${woodies_config}')
    	passed_count++
    } else {
    	println('✗ FAILED - Woodies CCI calculation failed')
    }
    println('')



    // Summary
    println('=========================================')
    println('Test Summary: ${passed_count}/${test_count} tests passed')
    println('')
    println('📊 INDICATOR TESTED:')
    println('  • Total: 66 indicators tested')
    println('')
    if passed_count == test_count {
        println('🎉 All tests passed! Your V language technical analysis library is complete!')
    } else {
        println('❌ Some tests failed. Please check the output above.')
    }
}
