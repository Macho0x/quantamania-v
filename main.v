import indicators

fn main() {
    println('V Language Technical Indicators Library')
    println('=====================================')

    
    // Sample data for testing
    sample_data := [
        indicators.OHLCV{open: 100.0, high: 102.0, low: 99.0, close: 101.0, volume: 1000.0},
        indicators.OHLCV{open: 101.0, high: 103.0, low: 100.0, close: 102.0, volume: 1100.0},
        indicators.OHLCV{open: 102.0, high: 104.0, low: 101.0, close: 103.0, volume: 1200.0},
        indicators.OHLCV{open: 103.0, high: 105.0, low: 102.0, close: 104.0, volume: 1300.0},
        indicators.OHLCV{open: 104.0, high: 106.0, low: 103.0, close: 105.0, volume: 1400.0},
        indicators.OHLCV{open: 105.0, high: 107.0, low: 104.0, close: 106.0, volume: 1500.0},
        indicators.OHLCV{open: 106.0, high: 108.0, low: 105.0, close: 107.0, volume: 1600.0},
        indicators.OHLCV{open: 107.0, high: 109.0, low: 106.0, close: 108.0, volume: 1700.0},
        indicators.OHLCV{open: 108.0, high: 110.0, low: 107.0, close: 109.0, volume: 1800.0},
        indicators.OHLCV{open: 109.0, high: 111.0, low: 108.0, close: 110.0, volume: 1900.0},
        indicators.OHLCV{open: 110.0, high: 112.0, low: 109.0, close: 111.0, volume: 2000.0},
        indicators.OHLCV{open: 111.0, high: 113.0, low: 110.0, close: 112.0, volume: 2100.0},
        indicators.OHLCV{open: 112.0, high: 114.0, low: 111.0, close: 113.0, volume: 2200.0},
        indicators.OHLCV{open: 113.0, high: 115.0, low: 112.0, close: 114.0, volume: 2300.0},
        indicators.OHLCV{open: 114.0, high: 116.0, low: 113.0, close: 115.0, volume: 2400.0},
        indicators.OHLCV{open: 115.0, high: 117.0, low: 114.0, close: 116.0, volume: 2500.0},
        indicators.OHLCV{open: 116.0, high: 118.0, low: 115.0, close: 117.0, volume: 2600.0},
        indicators.OHLCV{open: 117.0, high: 119.0, low: 116.0, close: 118.0, volume: 2700.0},
        indicators.OHLCV{open: 118.0, high: 120.0, low: 117.0, close: 119.0, volume: 2800.0},
        indicators.OHLCV{open: 119.0, high: 121.0, low: 118.0, close: 120.0, volume: 2900.0},
    ]
    
    println('Testing all indicators with sample data...')
    println('========================================')
    
    // Test 1: Simple Moving Average
    sma_config := indicators.SMAConfig{period: 5}
    if validated_config := sma_config.validate() {
        result := indicators.sma(sample_data, validated_config)
        println('✓ SMA: ${result.len} values calculated')
    }
    
    // Test 2: Exponential Moving Average
    ema_config := indicators.EMAConfig{period: 5}
    if validated_config := ema_config.validate() {
        result := indicators.ema(sample_data, validated_config)
        println('✓ EMA: ${result.len} values calculated')
    }
    
    // Test 3: Bollinger Bands
    bb_config := indicators.BollingerConfig{period: 5, num_std_dev: 2.0}
    if validated_config := bb_config.validate() {
        upper, middle, lower := indicators.bollinger_bands(sample_data, validated_config)
        println('✓ Bollinger Bands: ${upper.len} values calculated')
    }
    
    // Test 4: RSI
    rsi_config := indicators.RSIConfig{period: 5}
    if validated_config := rsi_config.validate() {
        result := indicators.rsi(sample_data, validated_config)
        println('✓ RSI: ${result.len} values calculated')
    }
    
    // Test 5: ADX
    adx_config := indicators.ADXConfig{period: 5}
    if validated_config := adx_config.validate() {
        adx_line, plus_di, minus_di := indicators.adx(sample_data, validated_config)
        println('✓ ADX: ${adx_line.len} values calculated')
    }
    
    // Test 6: MACD
    macd_config := indicators.MACDConfig{short_period: 3, long_period: 6, signal_period: 3}
    if validated_config := macd_config.validate() {
        macd_line, signal_line, histogram := indicators.macd(sample_data, macd_config)
        println('✓ MACD: ${macd_line.len} values calculated')
    }
    
    // Test 7: Parabolic SAR
    psar_config := indicators.ParabolicSARConfig{acceleration: 0.02, max_acceleration: 0.2}
    if validated_config := psar_config.validate() {
        result := indicators.parabolic_sar(sample_data, psar_config)
        println('✓ Parabolic SAR: ${result.len} values calculated')
    }
    
    // Test 8: Ichimoku Cloud
    ichimoku_config := indicators.IchimokuConfig{tenkan_period: 3, kijun_period: 5, senkou_b_period: 7}
    if validated_config := ichimoku_config.validate() {
        tenkan, kijun, senkou_a, senkou_b, chikou := indicators.ichimoku_cloud(sample_data, ichimoku_config)
        println('✓ Ichimoku Cloud: ${tenkan.len} values calculated')
    }
    
    // Test 9: Stochastic Oscillator
    stoch_config := indicators.StochasticConfig{k_period: 5, d_period: 3}
    if validated_config := stoch_config.validate() {
        k_line, d_line := indicators.stochastic_oscillator(sample_data, stoch_config)
        println('✓ Stochastic: ${k_line.len} values calculated')
    }
    
    // Test 10: Williams %R
    williams_config := indicators.WilliamsRConfig{period: 5}
    if validated_config := williams_config.validate() {
        result := indicators.williams_percent_r(sample_data, williams_config)
        println('✓ Williams %R: ${result.len} values calculated')
    }
    
    // Test 11: CCI
    cci_config := indicators.CCIConfig{period: 5}
    if validated_config := cci_config.validate() {
        result := indicators.cci(sample_data, cci_config)
        println('✓ CCI: ${result.len} values calculated')
    }
    
    // Test 12: OBV
    obv_result := indicators.on_balance_volume(sample_data)
    println('✓ OBV: ${obv_result.len} values calculated')

    // Test 13: Accumulation/Distribution Line
    ad_result := indicators.accumulation_distribution_line(sample_data)
    println('✓ A/D Line: ${ad_result.len} values calculated')

    // Test 14: Chaikin Money Flow
    cmf_config := indicators.CMFConfig{period: 5}
    if validated_config := cmf_config.validate() {
        cmf_result := indicators.chaikin_money_flow(sample_data, cmf_config)
        println('✓ CMF: ${cmf_result.len} values calculated')
    }
    
    // Test 15: ATR
    atr_config := indicators.ATRConfig{period: 5}
    if validated_config := atr_config.validate() {
        atr_result := indicators.average_true_range(sample_data, atr_config)
        println('✓ ATR: ${atr_result.len} values calculated')
    }

    // Test 16: Keltner Channels
    keltner_config := indicators.KeltnerConfig{period: 5, atr_multiplier: 2.0}
    if validated_config := keltner_config.validate() {
        upper, middle, lower := indicators.keltner_channels(sample_data, keltner_config)
        println('✓ Keltner Channels: ${upper.len} values calculated')
    }

    // Test 17: VWAP
    vwap_result := indicators.vwap(sample_data)
    println('✓ VWAP: ${vwap_result.len} values calculated')

    // Test 18: Awesome Oscillator
    ao_config := indicators.AwesomeOscillatorConfig{short_period: 3, long_period: 5}
    if validated_config := ao_config.validate() {
        ao_result := indicators.awesome_oscillator(sample_data, ao_config)
        println('✓ Awesome Oscillator: ${ao_result.len} values calculated')
    }
    
    // Test 19: Ultimate Oscillator
    uo_config := indicators.UltimateOscillatorConfig{period1: 3, period2: 5, period3: 7}
    if validated_config := uo_config.validate() {
        uo_result := indicators.ultimate_oscillator(sample_data, uo_config)
        println('✓ Ultimate Oscillator: ${uo_result.len} values calculated')
    }

    // Test 20: TRIX
    trix_config := indicators.TRIXConfig{period: 5}
    if validated_config := trix_config.validate() {
        trix_result := indicators.trix(sample_data, trix_config)
        println('✓ TRIX: ${trix_result.len} values calculated')
    }

    // Test 21: Donchian Channels
    donchian_config := indicators.DonchianConfig{period: 5}
    if validated_config := donchian_config.validate() {
        upper, middle, lower := indicators.donchian_channels(sample_data, donchian_config)
        println('✓ Donchian Channels: ${upper.len} values calculated')
    }

    // Test 22: Wilder's Smoothing
    wilders_config := indicators.WildersConfig{period: 5}
    if validated_config := wilders_config.validate() {
        wilders_result := indicators.wilders_smoothing(sample_data, wilders_config)
        println('✓ Wilder\'s Smoothing: ${wilders_result.len} values calculated')
    }

    // Test 23: Rate of Change
    roc_config := indicators.ROCConfig{period: 5}
    if validated_config := roc_config.validate() {
        roc_result := indicators.rate_of_change(sample_data, roc_config)
        println('✓ ROC: ${roc_result.len} values calculated')
    }
    
    // Test 24: Money Flow Index
    mfi_config := indicators.MFIConfig{period: 5}
    if validated_config := mfi_config.validate() {
        mfi_result := indicators.money_flow_index(sample_data, mfi_config)
        println('✓ MFI: ${mfi_result.len} values calculated')
    }

    // Test 25: Stochastic RSI
    stoch_rsi_config := indicators.StochasticRSIConfig{rsi_period: 5, k_period: 5, d_period: 3}
    if validated_config := stoch_rsi_config.validate() {
        k_line, d_line := indicators.stochastic_rsi(sample_data, stoch_rsi_config)
        println('✓ Stochastic RSI: ${k_line.len} values calculated')
    }
    
    // Test 26: Know Sure Thing
    kst_config := indicators.KSTConfig{
        roc1_period: 3
        roc2_period: 4
        roc3_period: 5
        roc4_period: 6
        sma1_period: 3
        sma2_period: 3
        sma3_period: 3
        sma4_period: 3
        signal_period: 3
    }
    if validated_config := kst_config.validate() {
        kst_line, signal_line := indicators.know_sure_thing(sample_data, kst_config)
        println('✓ KST: ${kst_line.len} values calculated')
    }
    
    // Test 27: Coppock Curve
    coppock_config := indicators.CoppockConfig{roc1_period: 3, roc2_period: 2, wma_period: 3}
    if validated_config := coppock_config.validate() {
        coppock_result := indicators.coppock_curve(sample_data, coppock_config)
        println('✓ Coppock Curve: ${coppock_result.len} values calculated')
    }

    // Test 28: Vortex Indicator
    vortex_config := indicators.VortexConfig{period: 5}
    if validated_config := vortex_config.validate() {
        vortex_plus, vortex_minus := indicators.vortex_indicator(sample_data, vortex_config)
        println('✓ Vortex Indicator: ${vortex_plus.len} values calculated')
    }

    // Test 29: Hull Moving Average
    hma_config := indicators.HMAConfig{period: 5}
    if validated_config := hma_config.validate() {
        hma_result := indicators.hull_moving_average(sample_data, hma_config)
        println('✓ HMA: ${hma_result.len} values calculated')
    }

    // Test 30: Linear Regression
    lr_config := indicators.LinearRegressionConfig{period: 5}
    if validated_config := lr_config.validate() {
        lr_result := indicators.linear_regression(sample_data, lr_config)
        println('✓ Linear Regression: ${lr_result.line.len} values calculated')
    }
    
    // Test 31: Volume Weighted Moving Average
    vwma_config := indicators.VWMAConfig{period: 5}
    if validated_config := vwma_config.validate() {
        vwma_result := indicators.volume_weighted_moving_average(sample_data, vwma_config)
        println('✓ VWMA: ${vwma_result.len} values calculated')
    }

    // Test 32: Double Exponential Moving Average
    dema_config := indicators.DEMAConfig{period: 5}
    if validated_config := dema_config.validate() {
        dema_result := indicators.double_exponential_moving_average(sample_data, dema_config)
        println('✓ DEMA: ${dema_result.len} values calculated')
    }

    // Test 33: Triple Exponential Moving Average
    tema_config := indicators.TEMAConfig{period: 5}
    if validated_config := tema_config.validate() {
        tema_result := indicators.triple_exponential_moving_average(sample_data, tema_config)
        println('✓ TEMA: ${tema_result.len} values calculated')
    }

    // Test 34: Adaptive Moving Average
    ama_config := indicators.AMAConfig{fast_period: 2, slow_period: 7}
    if validated_config := ama_config.validate() {
        ama_result := indicators.adaptive_moving_average(sample_data, ama_config)
        println('✓ AMA: ${ama_result.len} values calculated')
    }

    // Test 35: Arnaud Legoux Moving Average
    alma_config := indicators.ALMAConfig{period: 5, offset: 0.85, sigma: 6.0}
    if validated_config := alma_config.validate() {
        alma_result := indicators.arnaud_legoux_moving_average(sample_data, alma_config)
        println('✓ ALMA: ${alma_result.len} values calculated')
    }
    
    // Test 36: Momentum
    momentum_config := indicators.MomentumConfig{period: 5}
    if validated_config := momentum_config.validate() {
        momentum_result := indicators.momentum(sample_data, momentum_config)
        println('✓ Momentum: ${momentum_result.len} values calculated')
    }

    // Test 37: Price Rate of Change
    proc_config := indicators.PROCConfig{period: 5}
    if validated_config := proc_config.validate() {
        proc_result := indicators.price_rate_of_change(sample_data, proc_config)
        println('✓ PROC: ${proc_result.len} values calculated')
    }

    // Test 38: Detrended Price Oscillator
    dpo_config := indicators.DPOConfig{period: 5}
    if validated_config := dpo_config.validate() {
        dpo_result := indicators.detrended_price_oscillator(sample_data, dpo_config)
        println('✓ DPO: ${dpo_result.len} values calculated')
    }

    // Test 39: Percentage Price Oscillator
    ppo_config := indicators.PPOConfig{fast_period: 3, slow_period: 6, signal_period: 3}
    if validated_config := ppo_config.validate() {
        ppo_result := indicators.percentage_price_oscillator(sample_data, ppo_config)
        println('✓ PPO: ${ppo_result.ppo_line.len} values calculated')
    }

    // Test 40: Chande Momentum Oscillator
    cmo_config := indicators.CMOConfig{period: 5}
    if validated_config := cmo_config.validate() {
        cmo_result := indicators.chande_momentum_oscillator(sample_data, cmo_config)
        println('✓ CMO: ${cmo_result.len} values calculated')
    }
    
    // Test 41: Fisher Transform
    fisher_config := indicators.FisherConfig{period: 5}
    if validated_config := fisher_config.validate() {
        fisher_result := indicators.fisher_transform(sample_data, fisher_config)
        println('✓ Fisher Transform: ${fisher_result.fisher.len} values calculated')
    }

    // Test 42: Ease of Movement
    emv_config := indicators.EMVConfig{period: 5}
    if validated_config := emv_config.validate() {
        emv_result := indicators.ease_of_movement(sample_data, emv_config)
        println('✓ EOM: ${emv_result.len} values calculated')
    }

    // Test 43: Standard Deviation
    stddev_config := indicators.StdDevConfig{period: 5}
    if validated_config := stddev_config.validate() {
        stddev_result := indicators.standard_deviation(sample_data, stddev_config)
        println('✓ Standard Deviation: ${stddev_result.len} values calculated')
    }

    // Test 44: Historical Volatility
    hv_config := indicators.HistoricalVolatilityConfig{period: 5}
    if validated_config := hv_config.validate() {
        hv_result := indicators.historical_volatility(sample_data, hv_config)
        println('✓ Historical Volatility: ${hv_result.len} values calculated')
    }

    // Test 45: Chaikin Volatility
    cv_config := indicators.ChaikinVolatilityConfig{period: 5}
    if validated_config := cv_config.validate() {
        cv_result := indicators.chaikin_volatility(sample_data, cv_config)
        println('✓ Chaikin Volatility: ${cv_result.len} values calculated')
    }

    // Test 46: Ulcer Index
    ulcer_config := indicators.UlcerIndexConfig{period: 5}
    if validated_config := ulcer_config.validate() {
        ulcer_result := indicators.ulcer_index(sample_data, ulcer_config)
        println('✓ Ulcer Index: ${ulcer_result.len} values calculated')
    }
    
    // Test 47: Gator Oscillator
    gator_config := indicators.GatorConfig{jaw_period: 3, teeth_period: 3, lips_period: 3}
    if validated_config := gator_config.validate() {
        gator_result := indicators.gator_oscillator(sample_data, gator_config)
        println('✓ Gator Oscillator: ${gator_result.upper_jaw.len} values calculated')
    }

    // Test 48: Force Index
    force_config := indicators.ForceIndexConfig{period: 5}
    if validated_config := force_config.validate() {
        force_result := indicators.force_index(sample_data, force_config)
        println('✓ Force Index: ${force_result.len} values calculated')
    }

    // Test 49: Elder Ray Index
    elder_config := indicators.ElderRayConfig{period: 5}
    if validated_config := elder_config.validate() {
        elder_result := indicators.elder_ray_index(sample_data, elder_config)
        println('✓ Elder Ray Index: ${elder_result.bull_power.len} values calculated')
    }

    // Test 50: Choppiness Index
    choppiness_config := indicators.ChoppinessConfig{period: 5}
    if validated_config := choppiness_config.validate() {
        choppiness_result := indicators.choppiness_index(sample_data, choppiness_config)
        println('✓ Choppiness Index: ${choppiness_result.len} values calculated')
    }

    // Test 51: True Strength Index
    tsi_config := indicators.TSIConfig{long_period: 5, short_period: 3}
    if validated_config := tsi_config.validate() {
        tsi_result := indicators.true_strength_index(sample_data, tsi_config)
        println('✓ True Strength Index: ${tsi_result.len} values calculated')
    }

    // Test 52: Volume Rate of Change
    volume_roc_config := indicators.VolumeROCConfig{period: 5}
    if validated_config := volume_roc_config.validate() {
        volume_roc_result := indicators.volume_rate_of_change(sample_data, volume_roc_config)
        println('✓ Volume ROC: ${volume_roc_result.len} values calculated')
    }

    // Test 53: Volume Price Trend
    vpt_config := indicators.VPTConfig{period: 5}
    if validated_config := vpt_config.validate() {
        vpt_result := indicators.volume_price_trend(sample_data, vpt_config)
        println('✓ Volume Price Trend: ${vpt_result.len} values calculated')
    }

    // Test 54: Negative Volume Index
    nvi_config := indicators.NVIConfig{period: 5}
    if validated_config := nvi_config.validate() {
        nvi_result := indicators.negative_volume_index(sample_data, nvi_config)
        println('✓ Negative Volume Index: ${nvi_result.len} values calculated')
    }

    // Test 55: Positive Volume Index
    pvi_config := indicators.PVIConfig{period: 5}
    if validated_config := pvi_config.validate() {
        pvi_result := indicators.positive_volume_index(sample_data, pvi_config)
        println('✓ Positive Volume Index: ${pvi_result.len} values calculated')
    }

    // Test 56: Money Flow Volume
    mfv_config := indicators.MFVConfig{period: 5}
    if validated_config := mfv_config.validate() {
        mfv_result := indicators.money_flow_volume(sample_data, mfv_config)
        println('✓ Money Flow Volume: ${mfv_result.len} values calculated')
    }

    // Test 57: Enhanced VWAP
    enhanced_vwap_config := indicators.EnhancedVWAPConfig{period: 5}
    if validated_config := enhanced_vwap_config.validate() {
        enhanced_result := indicators.enhanced_vwap(sample_data, enhanced_vwap_config)
        println('✓ Enhanced VWAP: ${enhanced_result.vwap.len} values calculated')
    }

    // Test 58: Money Flow Oscillator
    mfo_config := indicators.MoneyFlowOscillatorConfig{period: 5}
    if validated_config := mfo_config.validate() {
        mfo_result := indicators.money_flow_oscillator(sample_data, mfo_config)
        println('✓ Money Flow Oscillator: ${mfo_result.len} values calculated')
    }

    // Test 59: Klinger Oscillator
    klinger_config := indicators.KlingerConfig{short_period: 3, long_period: 5, signal_period: 3}
    if validated_config := klinger_config.validate() {
        klinger_result := indicators.klinger_oscillator(sample_data, klinger_config)
        println('✓ Klinger Oscillator: ${klinger_result.kvo_line.len} values calculated')
    }

    // Test 60: Volume Weighted MACD
    vw_macd_config := indicators.VolumeWeightedMACDConfig{fast_period: 3, slow_period: 6, signal_period: 3}
    if validated_config := vw_macd_config.validate() {
        vw_macd_result := indicators.volume_weighted_macd(sample_data, vw_macd_config)
        println('✓ Volume Weighted MACD: ${vw_macd_result.macd_line.len} values calculated')
    }

    // Test 61: Pivot Points
    pivot_config := indicators.PivotPointsConfig{}
    if validated_config := pivot_config.validate() {
        pivot_result := indicators.pivot_points(sample_data, pivot_config)
        println('✓ Pivot Points: ${pivot_result.pivot_point.len} values calculated')
    }

    // Test 62: Fibonacci Retracements
    fibonacci_config := indicators.FibonacciConfig{lookback_period: 5}
    if validated_config := fibonacci_config.validate() {
        fib_result := indicators.fibonacci_retracements(sample_data, fibonacci_config)
        println('✓ Fibonacci Retracements: ${fib_result.level_0_618.len} values calculated')
    }

    // Test 63: Price Channels
    price_channels_config := indicators.PriceChannelsConfig{period: 5}
    if validated_config := price_channels_config.validate() {
        channels_result := indicators.price_channels(sample_data, price_channels_config)
        println('✓ Price Channels: ${channels_result.upper_channel.len} values calculated')
    }

    // Test 64: Andrews Pitchfork
    andrews_config := indicators.AndrewsPitchforkConfig{}
    if validated_config := andrews_config.validate() {
        andrews_result := indicators.andrews_pitchfork(sample_data, andrews_config)
        println('✓ Andrews Pitchfork: ${andrews_result.median_line.len} values calculated')
    }

    // Test 65: Woodies CCI
    woodies_config := indicators.WoodiesCCIConfig{cci_period: 5, tlb_period: 3}
    if validated_config := woodies_config.validate() {
        cci_line, tlb_line := indicators.woodies_cci(sample_data, woodies_config)
        println('✓ Woodies CCI: ${cci_line.len} values calculated')
    }

    // Test 66: Volume Profile
    volume_profile_config := indicators.VolumeProfileConfig{num_bins: 10}
    if validated_config := volume_profile_config.validate() {
        profile_result := indicators.volume_profile(sample_data, volume_profile_config)
        println('✓ Volume Profile: ${profile_result.volume_levels.len} levels calculated')
    }

    println('')
    println('All indicators tested successfully!')
    println('Total indicators: 66')
}
