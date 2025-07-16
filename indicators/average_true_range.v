module indicators

// average_true_range calculates the ATR.
pub fn average_true_range(data []OHLCV, config ATRConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len < period {
		return []f64{}
	}

	mut true_ranges := []f64{}
	for i := 1; i < data.len; i++ {
		prev_close := data[i - 1].close
		high := data[i].high
		low := data[i].low

		tr1 := high - low
		tr2 := if high - prev_close > 0 { high - prev_close } else { prev_close - high }
		tr3 := if low - prev_close > 0 { low - prev_close } else { prev_close - low }
		max_tr := if tr1 > tr2 { tr1 } else { tr2 }
		tr := if max_tr > tr3 { max_tr } else { tr3 }
		true_ranges << tr
	}

	// ATR is the Wilder's Smoothing of the True Range values
	wilders_config := WildersConfig{period: period}
	atr_values := wilders_smoothing_from_values(true_ranges, wilders_config)
	return atr_values
}


