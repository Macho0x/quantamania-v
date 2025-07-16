import indicators
import time
import math

struct IndicatorTiming {
    name string
    times []i64
}

struct BenchmarkStats {
    mean f64
    stddev f64
    min i64
    max i64
    trimmed_count int
}

fn calculate_stats(times []i64) BenchmarkStats {
    if times.len == 0 {
        return BenchmarkStats{}
    }

    mut sorted_times := times.clone()
    sorted_times.sort()

    // Remove bottom 200 and top 200 (or proportionally if less than 1000 runs)
    trim_count := if times.len >= 1000 { 200 } else { times.len / 5 }
    mut start_idx := trim_count
    mut end_idx := times.len - trim_count

    if start_idx >= end_idx {
        // If we can't trim properly, use all data
        start_idx = 0
        end_idx = times.len
    }

    trimmed := sorted_times[start_idx..end_idx].clone()

    // Calculate mean
    mut sum := f64(0)
    for t in trimmed {
        sum += f64(t)
    }
    mean := sum / trimmed.len

    // Calculate standard deviation
    mut variance_sum := f64(0)
    for t in trimmed {
        diff := f64(t) - mean
        variance_sum += diff * diff
    }
    stddev := math.sqrt(variance_sum / trimmed.len)

    return BenchmarkStats{
        mean: mean
        stddev: stddev
        min: trimmed[0]
        max: trimmed[trimmed.len - 1]
        trimmed_count: trimmed.len
    }
}

fn benchmark_indicator(name string, benchmark_fn fn()) i64 {
    start := time.now()
    benchmark_fn()
    return time.since(start).nanoseconds()
}

fn main() {
    // You can adjust this for quick testing (e.g., 100) or full benchmarking (1000)
    runs := 1000
    println('V Language Technical Indicators Benchmark Suite')
    println('===============================================')
    println('Running $runs iterations of each indicator...')
    println('')

    // Test data sets (same as test_suite.v)
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

    // Extended test data (same as test_data_3 from test_suite.v)
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
    ]

    mut indicator_timings := []IndicatorTiming{}
    mut overall_times := []i64{}

    // Benchmark each indicator
    println('Benchmarking individual indicators...')
    println('')

    // 1. Simple Moving Average (SMA)
    mut sma_times := []i64{}
    sma_config := indicators.SMAConfig{period: 5}
    validated_sma_config := sma_config.validate() or { panic('Invalid SMA config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('SMA', fn [test_data_1, validated_sma_config] () {
            _ := indicators.sma(test_data_1, validated_sma_config)
        })
        sma_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Simple Moving Average (SMA)', times: sma_times}

    // 2. Exponential Moving Average (EMA)
    mut ema_times := []i64{}
    ema_config := indicators.EMAConfig{period: 5}
    validated_ema_config := ema_config.validate() or { panic('Invalid EMA config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('EMA', fn [test_data_1, validated_ema_config] () {
            _ := indicators.ema(test_data_1, validated_ema_config)
        })
        ema_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Exponential Moving Average (EMA)', times: ema_times}

    // 3. Bollinger Bands
    mut bollinger_times := []i64{}
    bollinger_config := indicators.BollingerConfig{period: 5, num_std_dev: 2.0}
    validated_bollinger_config := bollinger_config.validate() or { panic('Invalid Bollinger config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Bollinger', fn [test_data_1, validated_bollinger_config] () {
            _, _, _ := indicators.bollinger_bands(test_data_1, validated_bollinger_config)
        })
        bollinger_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Bollinger Bands', times: bollinger_times}

    // 4. Relative Strength Index (RSI)
    mut rsi_times := []i64{}
    rsi_config := indicators.RSIConfig{period: 14}
    validated_rsi_config := rsi_config.validate() or { panic('Invalid RSI config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('RSI', fn [test_data_2, validated_rsi_config] () {
            _ := indicators.rsi(test_data_2, validated_rsi_config)
        })
        rsi_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Relative Strength Index (RSI)', times: rsi_times}

    // 5. Average Directional Index (ADX)
    mut adx_times := []i64{}
    adx_config := indicators.ADXConfig{period: 14}
    validated_adx_config := adx_config.validate() or { panic('Invalid ADX config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('ADX', fn [test_data_3, validated_adx_config] () {
            _, _, _ := indicators.adx(test_data_3, validated_adx_config)
        })
        adx_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Average Directional Index (ADX)', times: adx_times}

    // 6. MACD
    mut macd_times := []i64{}
    macd_config := indicators.MACDConfig{short_period: 12, long_period: 26, signal_period: 9}
    validated_macd_config := macd_config.validate() or { panic('Invalid MACD config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('MACD', fn [test_data_3, validated_macd_config] () {
            _, _, _ := indicators.macd(test_data_3, validated_macd_config)
        })
        macd_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Moving Average Convergence Divergence (MACD)', times: macd_times}

    // 7. Parabolic SAR
    mut sar_times := []i64{}
    sar_config := indicators.ParabolicSARConfig{acceleration: 0.02, max_acceleration: 0.2}
    validated_sar_config := sar_config.validate() or { panic('Invalid SAR config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('SAR', fn [test_data_3, validated_sar_config] () {
            _ := indicators.parabolic_sar(test_data_3, validated_sar_config)
        })
        sar_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Parabolic SAR', times: sar_times}

    // 8. Ichimoku Cloud
    mut ichimoku_times := []i64{}
    ichimoku_config := indicators.IchimokuConfig{tenkan_period: 9, kijun_period: 26, senkou_b_period: 52}
    validated_ichimoku_config := ichimoku_config.validate() or { panic('Invalid Ichimoku config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Ichimoku', fn [test_data_3, validated_ichimoku_config] () {
            _, _, _, _, _ := indicators.ichimoku_cloud(test_data_3, validated_ichimoku_config)
        })
        ichimoku_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Ichimoku Cloud', times: ichimoku_times}

    // 9. Stochastic Oscillator
    mut stochastic_times := []i64{}
    stochastic_config := indicators.StochasticConfig{k_period: 14, d_period: 3}
    validated_stochastic_config := stochastic_config.validate() or { panic('Invalid Stochastic config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Stochastic', fn [test_data_3, validated_stochastic_config] () {
            _, _ := indicators.stochastic_oscillator(test_data_3, validated_stochastic_config)
        })
        stochastic_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Stochastic Oscillator', times: stochastic_times}

    // 10. Williams %R
    mut williams_times := []i64{}
    williams_config := indicators.WilliamsRConfig{period: 14}
    validated_williams_config := williams_config.validate() or { panic('Invalid Williams config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Williams', fn [test_data_3, validated_williams_config] () {
            _ := indicators.williams_percent_r(test_data_3, validated_williams_config)
        })
        williams_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Williams %R', times: williams_times}

    // 11. Stochastic RSI (as example of more complex indicator)
    mut stoch_rsi_times := []i64{}
    stoch_rsi_config := indicators.StochasticRSIConfig{rsi_period: 14, k_period: 14, d_period: 3}
    validated_stoch_rsi_config := stoch_rsi_config.validate() or { panic('Invalid Stochastic RSI config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Stochastic RSI', fn [test_data_3, validated_stoch_rsi_config] () {
            _, _ := indicators.stochastic_rsi(test_data_3, validated_stoch_rsi_config)
        })
        stoch_rsi_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Stochastic RSI', times: stoch_rsi_times}

    // 12. Commodity Channel Index (CCI)
    mut cci_times := []i64{}
    cci_config := indicators.CCIConfig{period: 20}
    validated_cci_config := cci_config.validate() or { panic('Invalid CCI config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('CCI', fn [test_data_3, validated_cci_config] () {
            _ := indicators.cci(test_data_3, validated_cci_config)
        })
        cci_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Commodity Channel Index (CCI)', times: cci_times}

    // 13. On-Balance Volume (OBV)
    mut obv_times := []i64{}
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('OBV', fn [test_data_3] () {
            _ := indicators.on_balance_volume(test_data_3)
        })
        obv_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'On-Balance Volume (OBV)', times: obv_times}

    // 14. Accumulation/Distribution Line
    mut ad_line_times := []i64{}
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('A/D Line', fn [test_data_3] () {
            _ := indicators.accumulation_distribution_line(test_data_3)
        })
        ad_line_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Accumulation/Distribution Line', times: ad_line_times}

    // 15. Chaikin Money Flow
    mut cmf_times := []i64{}
    cmf_config := indicators.CMFConfig{period: 20}
    validated_cmf_config := cmf_config.validate() or { panic('Invalid CMF config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('CMF', fn [test_data_3, validated_cmf_config] () {
            _ := indicators.chaikin_money_flow(test_data_3, validated_cmf_config)
        })
        cmf_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Chaikin Money Flow', times: cmf_times}

    // 16. Average True Range (ATR)
    mut atr_times := []i64{}
    atr_config := indicators.ATRConfig{period: 14}
    validated_atr_config := atr_config.validate() or { panic('Invalid ATR config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('ATR', fn [test_data_3, validated_atr_config] () {
            _ := indicators.average_true_range(test_data_3, validated_atr_config)
        })
        atr_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Average True Range (ATR)', times: atr_times}

    // 17. Keltner Channels
    mut keltner_times := []i64{}
    keltner_config := indicators.KeltnerConfig{period: 20, atr_multiplier: 2.0}
    validated_keltner_config := keltner_config.validate() or { panic('Invalid Keltner config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Keltner', fn [test_data_3, validated_keltner_config] () {
            _, _, _ := indicators.keltner_channels(test_data_3, validated_keltner_config)
        })
        keltner_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Keltner Channels', times: keltner_times}

    // 18. Volume Weighted Average Price (VWAP)
    mut vwap_times := []i64{}
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('VWAP', fn [test_data_3] () {
            _ := indicators.vwap(test_data_3)
        })
        vwap_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Volume Weighted Average Price (VWAP)', times: vwap_times}

    // 19. Awesome Oscillator
    mut awesome_times := []i64{}
    awesome_config := indicators.AwesomeOscillatorConfig{short_period: 5, long_period: 34}
    validated_awesome_config := awesome_config.validate() or { panic('Invalid Awesome config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Awesome', fn [test_data_3, validated_awesome_config] () {
            _ := indicators.awesome_oscillator(test_data_3, validated_awesome_config)
        })
        awesome_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Awesome Oscillator', times: awesome_times}

    // 20. Ultimate Oscillator
    mut ultimate_times := []i64{}
    ultimate_config := indicators.UltimateOscillatorConfig{period1: 7, period2: 14, period3: 28}
    validated_ultimate_config := ultimate_config.validate() or { panic('Invalid Ultimate config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Ultimate', fn [test_data_3, validated_ultimate_config] () {
            _ := indicators.ultimate_oscillator(test_data_3, validated_ultimate_config)
        })
        ultimate_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Ultimate Oscillator', times: ultimate_times}

    // 21. TRIX
    mut trix_times := []i64{}
    trix_config := indicators.TRIXConfig{period: 15}
    validated_trix_config := trix_config.validate() or { panic('Invalid TRIX config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('TRIX', fn [test_data_3, validated_trix_config] () {
            _ := indicators.trix(test_data_3, validated_trix_config)
        })
        trix_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'TRIX', times: trix_times}

    // 22. Donchian Channels
    mut donchian_times := []i64{}
    donchian_config := indicators.DonchianConfig{period: 20}
    validated_donchian_config := donchian_config.validate() or { panic('Invalid Donchian config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Donchian', fn [test_data_3, validated_donchian_config] () {
            _, _, _ := indicators.donchian_channels(test_data_3, validated_donchian_config)
        })
        donchian_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Donchian Channels', times: donchian_times}

    // 23. Wilder's Smoothing
    mut wilders_times := []i64{}
    wilders_config := indicators.WildersConfig{period: 14}
    validated_wilders_config := wilders_config.validate() or { panic('Invalid Wilders config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Wilders', fn [test_data_3, validated_wilders_config] () {
            _ := indicators.wilders_smoothing(test_data_3, validated_wilders_config)
        })
        wilders_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Wilder\'s Smoothing', times: wilders_times}

    // 24. Rate of Change (ROC)
    mut roc_times := []i64{}
    roc_config := indicators.ROCConfig{period: 10}
    validated_roc_config := roc_config.validate() or { panic('Invalid ROC config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('ROC', fn [test_data_3, validated_roc_config] () {
            _ := indicators.rate_of_change(test_data_3, validated_roc_config)
        })
        roc_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Rate of Change (ROC)', times: roc_times}

    // 25. Money Flow Index
    mut mfi_times := []i64{}
    mfi_config := indicators.MFIConfig{period: 14}
    validated_mfi_config := mfi_config.validate() or { panic('Invalid MFI config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('MFI', fn [test_data_3, validated_mfi_config] () {
            _ := indicators.money_flow_index(test_data_3, validated_mfi_config)
        })
        mfi_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Money Flow Index', times: mfi_times}

    // 26. Know Sure Thing (KST)
    mut kst_times := []i64{}
    kst_config := indicators.KSTConfig{
        roc1_period: 10, roc2_period: 15, roc3_period: 20, roc4_period: 30,
        sma1_period: 10, sma2_period: 10, sma3_period: 10, sma4_period: 15,
        signal_period: 9
    }
    validated_kst_config := kst_config.validate() or { panic('Invalid KST config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('KST', fn [test_data_3, validated_kst_config] () {
            _, _ := indicators.know_sure_thing(test_data_3, validated_kst_config)
        })
        kst_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Know Sure Thing (KST)', times: kst_times}

    // 27. Coppock Curve
    mut coppock_times := []i64{}
    coppock_config := indicators.CoppockConfig{roc1_period: 14, roc2_period: 11, wma_period: 10}
    validated_coppock_config := coppock_config.validate() or { panic('Invalid Coppock config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Coppock', fn [test_data_3, validated_coppock_config] () {
            _ := indicators.coppock_curve(test_data_3, validated_coppock_config)
        })
        coppock_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Coppock Curve', times: coppock_times}

    // 28. Vortex Indicator
    mut vortex_times := []i64{}
    vortex_config := indicators.VortexConfig{period: 14}
    validated_vortex_config := vortex_config.validate() or { panic('Invalid Vortex config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Vortex', fn [test_data_3, validated_vortex_config] () {
            _, _ := indicators.vortex_indicator(test_data_3, validated_vortex_config)
        })
        vortex_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Vortex Indicator', times: vortex_times}

    // 29. Hull Moving Average (HMA)
    mut hma_times := []i64{}
    hma_config := indicators.HMAConfig{period: 20}
    validated_hma_config := hma_config.validate() or { panic('Invalid HMA config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('HMA', fn [test_data_3, validated_hma_config] () {
            _ := indicators.hull_moving_average(test_data_3, validated_hma_config)
        })
        hma_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Hull Moving Average (HMA)', times: hma_times}

    // 30. Linear Regression
    mut linear_reg_times := []i64{}
    linear_reg_config := indicators.LinearRegressionConfig{period: 20}
    validated_linear_reg_config := linear_reg_config.validate() or { panic('Invalid Linear Regression config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Linear Regression', fn [test_data_3, validated_linear_reg_config] () {
            _ := indicators.linear_regression(test_data_3, validated_linear_reg_config)
        })
        linear_reg_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Linear Regression', times: linear_reg_times}

    // 31. Volume Weighted Moving Average (VWMA)
    mut vwma_times := []i64{}
    vwma_config := indicators.VWMAConfig{period: 20}
    validated_vwma_config := vwma_config.validate() or { panic('Invalid VWMA config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('VWMA', fn [test_data_3, validated_vwma_config] () {
            _ := indicators.volume_weighted_moving_average(test_data_3, validated_vwma_config)
        })
        vwma_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Volume Weighted Moving Average (VWMA)', times: vwma_times}

    // 32. Double Exponential Moving Average (DEMA)
    mut dema_times := []i64{}
    dema_config := indicators.DEMAConfig{period: 20}
    validated_dema_config := dema_config.validate() or { panic('Invalid DEMA config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('DEMA', fn [test_data_3, validated_dema_config] () {
            _ := indicators.double_exponential_moving_average(test_data_3, validated_dema_config)
        })
        dema_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Double Exponential Moving Average (DEMA)', times: dema_times}

    // 33. Triple Exponential Moving Average (TEMA)
    mut tema_times := []i64{}
    tema_config := indicators.TEMAConfig{period: 20}
    validated_tema_config := tema_config.validate() or { panic('Invalid TEMA config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('TEMA', fn [test_data_3, validated_tema_config] () {
            _ := indicators.triple_exponential_moving_average(test_data_3, validated_tema_config)
        })
        tema_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Triple Exponential Moving Average (TEMA)', times: tema_times}

    // 34. Adaptive Moving Average (AMA)
    mut ama_times := []i64{}
    ama_config := indicators.AMAConfig{fast_period: 2, slow_period: 30}
    validated_ama_config := ama_config.validate() or { panic('Invalid AMA config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('AMA', fn [test_data_3, validated_ama_config] () {
            _ := indicators.adaptive_moving_average(test_data_3, validated_ama_config)
        })
        ama_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Adaptive Moving Average (AMA)', times: ama_times}

    // 35. Arnaud Legoux Moving Average (ALMA)
    mut alma_times := []i64{}
    alma_config := indicators.ALMAConfig{period: 20, sigma: 6.0, offset: 0.85}
    validated_alma_config := alma_config.validate() or { panic('Invalid ALMA config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('ALMA', fn [test_data_3, validated_alma_config] () {
            _ := indicators.arnaud_legoux_moving_average(test_data_3, validated_alma_config)
        })
        alma_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Arnaud Legoux Moving Average (ALMA)', times: alma_times}

    // 36. Momentum
    mut momentum_times := []i64{}
    momentum_config := indicators.MomentumConfig{period: 10}
    validated_momentum_config := momentum_config.validate() or { panic('Invalid Momentum config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Momentum', fn [test_data_3, validated_momentum_config] () {
            _ := indicators.momentum(test_data_3, validated_momentum_config)
        })
        momentum_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Momentum', times: momentum_times}

    // 37. Price Rate of Change (PROC)
    mut proc_times := []i64{}
    proc_config := indicators.PROCConfig{period: 10}
    validated_proc_config := proc_config.validate() or { panic('Invalid PROC config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('PROC', fn [test_data_3, validated_proc_config] () {
            _ := indicators.price_rate_of_change(test_data_3, validated_proc_config)
        })
        proc_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Price Rate of Change (PROC)', times: proc_times}

    // 38. Detrended Price Oscillator (DPO)
    mut dpo_times := []i64{}
    dpo_config := indicators.DPOConfig{period: 20}
    validated_dpo_config := dpo_config.validate() or { panic('Invalid DPO config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('DPO', fn [test_data_3, validated_dpo_config] () {
            _ := indicators.detrended_price_oscillator(test_data_3, validated_dpo_config)
        })
        dpo_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Detrended Price Oscillator (DPO)', times: dpo_times}

    // 39. Percentage Price Oscillator (PPO)
    mut ppo_times := []i64{}
    ppo_config := indicators.PPOConfig{fast_period: 12, slow_period: 26, signal_period: 9}
    validated_ppo_config := ppo_config.validate() or { panic('Invalid PPO config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('PPO', fn [test_data_3, validated_ppo_config] () {
            _ := indicators.percentage_price_oscillator(test_data_3, validated_ppo_config)
        })
        ppo_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Percentage Price Oscillator (PPO)', times: ppo_times}

    // 40. Chande Momentum Oscillator (CMO)
    mut cmo_times := []i64{}
    cmo_config := indicators.CMOConfig{period: 14}
    validated_cmo_config := cmo_config.validate() or { panic('Invalid CMO config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('CMO', fn [test_data_3, validated_cmo_config] () {
            _ := indicators.chande_momentum_oscillator(test_data_3, validated_cmo_config)
        })
        cmo_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Chande Momentum Oscillator (CMO)', times: cmo_times}

    // 41. Fisher Transform
    mut fisher_times := []i64{}
    fisher_config := indicators.FisherConfig{period: 10}
    validated_fisher_config := fisher_config.validate() or { panic('Invalid Fisher config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Fisher', fn [test_data_3, validated_fisher_config] () {
            _ := indicators.fisher_transform(test_data_3, validated_fisher_config)
        })
        fisher_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Fisher Transform', times: fisher_times}

    // 42. Ease of Movement (EOM)
    mut eom_times := []i64{}
    eom_config := indicators.EMVConfig{period: 14}
    validated_eom_config := eom_config.validate() or { panic('Invalid EOM config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('EOM', fn [test_data_3, validated_eom_config] () {
            _ := indicators.ease_of_movement(test_data_3, validated_eom_config)
        })
        eom_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Ease of Movement (EOM)', times: eom_times}

    // 43. Standard Deviation
    mut std_dev_times := []i64{}
    std_dev_config := indicators.StdDevConfig{period: 20}
    validated_std_dev_config := std_dev_config.validate() or { panic('Invalid StdDev config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('StdDev', fn [test_data_3, validated_std_dev_config] () {
            _ := indicators.standard_deviation(test_data_3, validated_std_dev_config)
        })
        std_dev_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Standard Deviation', times: std_dev_times}

    // 44. Historical Volatility
    mut hist_vol_times := []i64{}
    hist_vol_config := indicators.HistoricalVolatilityConfig{period: 20}
    validated_hist_vol_config := hist_vol_config.validate() or { panic('Invalid HistVol config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('HistVol', fn [test_data_3, validated_hist_vol_config] () {
            _ := indicators.historical_volatility(test_data_3, validated_hist_vol_config)
        })
        hist_vol_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Historical Volatility', times: hist_vol_times}

    // 45. Chaikin Volatility
    mut chaikin_vol_times := []i64{}
    chaikin_vol_config := indicators.ChaikinVolatilityConfig{period: 10}
    validated_chaikin_vol_config := chaikin_vol_config.validate() or { panic('Invalid ChaikinVol config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('ChaikinVol', fn [test_data_3, validated_chaikin_vol_config] () {
            _ := indicators.chaikin_volatility(test_data_3, validated_chaikin_vol_config)
        })
        chaikin_vol_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Chaikin Volatility', times: chaikin_vol_times}

    // 46. Ulcer Index
    mut ulcer_times := []i64{}
    ulcer_config := indicators.UlcerIndexConfig{period: 14}
    validated_ulcer_config := ulcer_config.validate() or { panic('Invalid Ulcer config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Ulcer', fn [test_data_3, validated_ulcer_config] () {
            _ := indicators.ulcer_index(test_data_3, validated_ulcer_config)
        })
        ulcer_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Ulcer Index', times: ulcer_times}

    // 47. Gator Oscillator
    mut gator_times := []i64{}
    gator_config := indicators.GatorConfig{jaw_period: 13, teeth_period: 8, lips_period: 5}
    validated_gator_config := gator_config.validate() or { panic('Invalid Gator config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Gator', fn [test_data_3, validated_gator_config] () {
            _ := indicators.gator_oscillator(test_data_3, validated_gator_config)
        })
        gator_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Gator Oscillator', times: gator_times}

    // 48. Volume Rate of Change (Volume ROC)
    mut volume_roc_times := []i64{}
    volume_roc_config := indicators.VolumeROCConfig{period: 25}
    validated_volume_roc_config := volume_roc_config.validate() or { panic('Invalid VolumeROC config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('VolumeROC', fn [test_data_3, validated_volume_roc_config] () {
            _ := indicators.volume_rate_of_change(test_data_3, validated_volume_roc_config)
        })
        volume_roc_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Volume Rate of Change (Volume ROC)', times: volume_roc_times}

    // 49. Volume Price Trend (VPT)
    mut vpt_times := []i64{}
    vpt_config := indicators.VPTConfig{period: 14}
    validated_vpt_config := vpt_config.validate() or { panic('Invalid VPT config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('VPT', fn [test_data_3, validated_vpt_config] () {
            _ := indicators.volume_price_trend(test_data_3, validated_vpt_config)
        })
        vpt_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Volume Price Trend (VPT)', times: vpt_times}

    // 50. Negative Volume Index (NVI)
    mut nvi_times := []i64{}
    nvi_config := indicators.NVIConfig{period: 20}
    validated_nvi_config := nvi_config.validate() or { panic('Invalid NVI config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('NVI', fn [test_data_3, validated_nvi_config] () {
            _ := indicators.negative_volume_index(test_data_3, validated_nvi_config)
        })
        nvi_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Negative Volume Index (NVI)', times: nvi_times}

    // 51. Positive Volume Index (PVI)
    mut pvi_times := []i64{}
    pvi_config := indicators.PVIConfig{period: 20}
    validated_pvi_config := pvi_config.validate() or { panic('Invalid PVI config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('PVI', fn [test_data_3, validated_pvi_config] () {
            _ := indicators.positive_volume_index(test_data_3, validated_pvi_config)
        })
        pvi_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Positive Volume Index (PVI)', times: pvi_times}

    // 52. Money Flow Volume (MFV)
    mut mfv_times := []i64{}
    mfv_config := indicators.MFVConfig{period: 14}
    validated_mfv_config := mfv_config.validate() or { panic('Invalid MFV config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('MFV', fn [test_data_3, validated_mfv_config] () {
            _ := indicators.money_flow_volume(test_data_3, validated_mfv_config)
        })
        mfv_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Money Flow Volume (MFV)', times: mfv_times}

    // 53. Enhanced VWAP
    mut enhanced_vwap_times := []i64{}
    enhanced_vwap_config := indicators.EnhancedVWAPConfig{period: 20}
    validated_enhanced_vwap_config := enhanced_vwap_config.validate() or { panic('Invalid Enhanced VWAP config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Enhanced VWAP', fn [test_data_3, validated_enhanced_vwap_config] () {
            _ := indicators.enhanced_vwap(test_data_3, validated_enhanced_vwap_config)
        })
        enhanced_vwap_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Enhanced VWAP', times: enhanced_vwap_times}

    // 54. Pivot Points
    mut pivot_times := []i64{}
    pivot_config := indicators.PivotPointsConfig{}
    validated_pivot_config := pivot_config.validate() or { panic('Invalid Pivot config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Pivot', fn [test_data_3, validated_pivot_config] () {
            _ := indicators.pivot_points(test_data_3, validated_pivot_config)
        })
        pivot_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Pivot Points', times: pivot_times}

    // 55. Fibonacci Retracements
    mut fib_times := []i64{}
    fib_config := indicators.FibonacciConfig{lookback_period: 20}
    validated_fib_config := fib_config.validate() or { panic('Invalid Fibonacci config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Fibonacci', fn [test_data_3, validated_fib_config] () {
            _ := indicators.fibonacci_retracements(test_data_3, validated_fib_config)
        })
        fib_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Fibonacci Retracements', times: fib_times}

    // 56. Price Channels
    mut price_channels_times := []i64{}
    price_channels_config := indicators.PriceChannelsConfig{period: 20}
    validated_price_channels_config := price_channels_config.validate() or { panic('Invalid Price Channels config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Price Channels', fn [test_data_3, validated_price_channels_config] () {
            _ := indicators.price_channels(test_data_3, validated_price_channels_config)
        })
        price_channels_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Price Channels', times: price_channels_times}

    // 57. Andrews Pitchfork
    mut andrews_times := []i64{}
    andrews_config := indicators.AndrewsPitchforkConfig{}
    validated_andrews_config := andrews_config.validate() or { panic('Invalid Andrews config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Andrews', fn [test_data_3, validated_andrews_config] () {
            _ := indicators.andrews_pitchfork(test_data_3, validated_andrews_config)
        })
        andrews_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Andrews Pitchfork', times: andrews_times}

    // 58. Elder Ray Index
    mut elder_ray_times := []i64{}
    elder_ray_config := indicators.ElderRayConfig{period: 13}
    validated_elder_ray_config := elder_ray_config.validate() or { panic('Invalid Elder Ray config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Elder Ray', fn [test_data_3, validated_elder_ray_config] () {
            _ := indicators.elder_ray_index(test_data_3, validated_elder_ray_config)
        })
        elder_ray_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Elder Ray Index', times: elder_ray_times}

    // 59. Force Index
    mut force_times := []i64{}
    force_config := indicators.ForceIndexConfig{period: 2}
    validated_force_config := force_config.validate() or { panic('Invalid Force config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Force', fn [test_data_3, validated_force_config] () {
            _ := indicators.force_index(test_data_3, validated_force_config)
        })
        force_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Force Index', times: force_times}

    // 60. True Strength Index (TSI)
    mut tsi_times := []i64{}
    tsi_config := indicators.TSIConfig{long_period: 25, short_period: 13}
    validated_tsi_config := tsi_config.validate() or { panic('Invalid TSI config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('TSI', fn [test_data_3, validated_tsi_config] () {
            _ := indicators.true_strength_index(test_data_3, validated_tsi_config)
        })
        tsi_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'True Strength Index (TSI)', times: tsi_times}

    // 61. Choppiness Index
    mut choppiness_times := []i64{}
    choppiness_config := indicators.ChoppinessConfig{period: 14}
    validated_choppiness_config := choppiness_config.validate() or { panic('Invalid Choppiness config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Choppiness', fn [test_data_3, validated_choppiness_config] () {
            _ := indicators.choppiness_index(test_data_3, validated_choppiness_config)
        })
        choppiness_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Choppiness Index', times: choppiness_times}

    // 62. Volume Profile
    mut volume_profile_times := []i64{}
    volume_profile_config := indicators.VolumeProfileConfig{num_bins: 10}
    validated_volume_profile_config := volume_profile_config.validate() or { panic('Invalid Volume Profile config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Volume Profile', fn [test_data_3, validated_volume_profile_config] () {
            _ := indicators.volume_profile(test_data_3, validated_volume_profile_config)
        })
        volume_profile_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Volume Profile', times: volume_profile_times}

    // 63. Money Flow Oscillator
    mut mfo_times := []i64{}
    mfo_config := indicators.MoneyFlowOscillatorConfig{period: 14}
    validated_mfo_config := mfo_config.validate() or { panic('Invalid MFO config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('MFO', fn [test_data_3, validated_mfo_config] () {
            _ := indicators.money_flow_oscillator(test_data_3, validated_mfo_config)
        })
        mfo_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Money Flow Oscillator', times: mfo_times}

    // 64. Volume Weighted MACD
    mut vw_macd_times := []i64{}
    vw_macd_config := indicators.VolumeWeightedMACDConfig{fast_period: 12, slow_period: 26, signal_period: 9}
    validated_vw_macd_config := vw_macd_config.validate() or { panic('Invalid VW MACD config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('VW MACD', fn [test_data_3, validated_vw_macd_config] () {
            _ := indicators.volume_weighted_macd(test_data_3, validated_vw_macd_config)
        })
        vw_macd_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Volume Weighted MACD', times: vw_macd_times}

    // 65. Klinger Oscillator
    mut klinger_times := []i64{}
    klinger_config := indicators.KlingerConfig{short_period: 34, long_period: 55, signal_period: 13}
    validated_klinger_config := klinger_config.validate() or { panic('Invalid Klinger config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Klinger', fn [test_data_3, validated_klinger_config] () {
            _ := indicators.klinger_oscillator(test_data_3, validated_klinger_config)
        })
        klinger_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Klinger Oscillator', times: klinger_times}

    // 66. Woodies CCI
    mut woodies_times := []i64{}
    woodies_config := indicators.WoodiesCCIConfig{cci_period: 14, tlb_period: 6}
    validated_woodies_config := woodies_config.validate() or { panic('Invalid Woodies config') }
    for _ in 0 .. runs {
        elapsed := benchmark_indicator('Woodies', fn [test_data_3, validated_woodies_config] () {
            _, _ := indicators.woodies_cci(test_data_3, validated_woodies_config)
        })
        woodies_times << elapsed
        overall_times << elapsed
    }
    indicator_timings << IndicatorTiming{name: 'Woodies CCI', times: woodies_times}

    // Add final progress indicator
    if runs >= 100 {
        println('Completed benchmarking all ${indicator_timings.len} indicators!')
        println('')
    }

    // Calculate and display results
    println('=== INDIVIDUAL INDICATOR BENCHMARK RESULTS ===')
    println('')

    mut fastest_indicator := ''
    mut fastest_time := f64(999999999)
    mut slowest_indicator := ''
    mut slowest_time := f64(0)

    for timing in indicator_timings {
        stats := calculate_stats(timing.times)

        // Convert nanoseconds to microseconds for display
        mean_us := stats.mean / 1000.0
        stddev_us := stats.stddev / 1000.0
        min_us := f64(stats.min) / 1000.0
        max_us := f64(stats.max) / 1000.0

        println('${timing.name}:')
        println('  Mean: ${mean_us:.2f} μs')
        println('  Std Dev: ${stddev_us:.2f} μs')
        println('  Min: ${min_us:.2f} μs')
        println('  Max: ${max_us:.2f} μs')
        println('  Trimmed samples: ${stats.trimmed_count}/${timing.times.len}')
        println('')

        // Track fastest and slowest
        if mean_us < fastest_time {
            fastest_time = mean_us
            fastest_indicator = timing.name
        }
        if mean_us > slowest_time {
            slowest_time = mean_us
            slowest_indicator = timing.name
        }
    }

    // Overall statistics
    overall_stats := calculate_stats(overall_times)
    overall_mean_us := overall_stats.mean / 1000.0
    overall_stddev_us := overall_stats.stddev / 1000.0
    overall_min_us := f64(overall_stats.min) / 1000.0
    overall_max_us := f64(overall_stats.max) / 1000.0

    println('=== OVERALL BENCHMARK RESULTS ===')
    println('')
    println('Total indicator executions: ${overall_times.len}')
    println('Overall Mean: ${overall_mean_us:.2f} μs')
    println('Overall Std Dev: ${overall_stddev_us:.2f} μs')
    println('Overall Min: ${overall_min_us:.2f} μs')
    println('Overall Max: ${overall_max_us:.2f} μs')
    println('Trimmed samples: ${overall_stats.trimmed_count}/${overall_times.len}')
    println('')

    println('=== PERFORMANCE SUMMARY ===')
    println('')
    println('Fastest Indicator: ${fastest_indicator} (${fastest_time:.2f} μs)')
    println('Slowest Indicator: ${slowest_indicator} (${slowest_time:.2f} μs)')
    println('Performance Ratio: ${slowest_time / fastest_time:.1f}x difference')
    println('')

    // Performance categories
    println('=== PERFORMANCE CATEGORIES ===')
    println('')
    mut ultra_fast := []string{}
    mut fast := []string{}
    mut medium := []string{}
    mut slow := []string{}

    for timing in indicator_timings {
        stats := calculate_stats(timing.times)
        mean_us := stats.mean / 1000.0

        if mean_us < 10.0 {
            ultra_fast << timing.name
        } else if mean_us < 50.0 {
            fast << timing.name
        } else if mean_us < 200.0 {
            medium << timing.name
        } else {
            slow << timing.name
        }
    }

    if ultra_fast.len > 0 {
        println('Ultra Fast (< 10 μs): ${ultra_fast.join(", ")}')
    }
    if fast.len > 0 {
        println('Fast (10-50 μs): ${fast.join(", ")}')
    }
    if medium.len > 0 {
        println('Medium (50-200 μs): ${medium.join(", ")}')
    }
    if slow.len > 0 {
        println('Slow (> 200 μs): ${slow.join(", ")}')
    }
}
