module indicators

// know_sure_thing calculates the Know Sure Thing (KST) indicator.
pub fn know_sure_thing(data []OHLCV, config KSTConfig) ([]f64, []f64) {
	validated_config := config.validate() or { return []f64{}, []f64{} }
	roc1 := validated_config.roc1_period
	roc2 := validated_config.roc2_period
	roc3 := validated_config.roc3_period
	roc4 := validated_config.roc4_period
	sma1 := validated_config.sma1_period
	sma2 := validated_config.sma2_period
	sma3 := validated_config.sma3_period
	sma4 := validated_config.sma4_period
	signal_period := validated_config.signal_period
	
    mut close_prices := []f64{}
	for d in data {
		close_prices << d.close
	}

    if close_prices.len < roc4 + sma4 {
        return []f64{}, []f64{}
    }

    // Calculate ROC values for each period
    roc1_config := ROCConfig{period: roc1}
    roc2_config := ROCConfig{period: roc2}
    roc3_config := ROCConfig{period: roc3}
    roc4_config := ROCConfig{period: roc4}
    
    roc1_values := rate_of_change(data, roc1_config)
    roc2_values := rate_of_change(data, roc2_config)
    roc3_values := rate_of_change(data, roc3_config)
    roc4_values := rate_of_change(data, roc4_config)

    // Apply SMA to ROC values
    sma_config1 := SMAConfig{period: sma1}
    sma_config2 := SMAConfig{period: sma2}
    sma_config3 := SMAConfig{period: sma3}
    sma_config4 := SMAConfig{period: sma4}
    
    sma_roc1 := sma_from_values(roc1_values, sma_config1)
    sma_roc2 := sma_from_values(roc2_values, sma_config2)
    sma_roc3 := sma_from_values(roc3_values, sma_config3)
    sma_roc4 := sma_from_values(roc4_values, sma_config4)

    // Align the lengths of the SMA series
    max_len := sma_roc4.len
    if sma_roc1.len < max_len || sma_roc2.len < max_len || sma_roc3.len < max_len {
        return []f64{}, []f64{}
    }
    aligned_sma1 := sma_roc1[sma_roc1.len - max_len..]
    aligned_sma2 := sma_roc2[sma_roc2.len - max_len..]
    aligned_sma3 := sma_roc3[sma_roc3.len - max_len..]

    mut kst_line := []f64{}
    for i := 0; i < max_len; i++ {
        kst_val := (aligned_sma1[i] * 1) + (aligned_sma2[i] * 2) + (aligned_sma3[i] * 3) + (sma_roc4[i] * 4)
        kst_line << kst_val
    }

    if kst_line.len < signal_period {
        return kst_line, []f64{}
    }

    signal_sma_config := SMAConfig{period: signal_period}
    signal_line := sma_from_values(kst_line, signal_sma_config)
    if kst_line.len < signal_line.len {
        return []f64{}, []f64{}
    }
    aligned_kst := kst_line[kst_line.len - signal_line.len..].clone()

    return aligned_kst, signal_line
}