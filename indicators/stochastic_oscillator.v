module indicators

// stochastic_oscillator calculates the Stochastic Oscillator.
pub fn stochastic_oscillator(data []OHLCV, config StochasticConfig) ([]f64, []f64) {
	validated_config := config.validate() or { return []f64{}, []f64{} }
	k_period := validated_config.k_period
	d_period := validated_config.d_period
	
	if data.len < k_period {
		return []f64{}, []f64{}
	}

	mut k_line := []f64{}
	for i := k_period - 1; i < data.len; i++ {
		mut highest_high := data[i - (k_period - 1)].high
		mut lowest_low := data[i - (k_period - 1)].low

		for j := i - (k_period - 1); j <= i; j++ {
			if data[j].high > highest_high {
				highest_high = data[j].high
			}
			if data[j].low < lowest_low {
				lowest_low = data[j].low
			}
		}
		
		stoch_k := if highest_high == lowest_low { 0.0 } else { (data[i].close - lowest_low) / (highest_high - lowest_low) * 100.0 }
		k_line << stoch_k
	}

	if k_line.len < d_period {
		return k_line, []f64{}
	}

	sma_config := SMAConfig{period: d_period}
	d_line := sma_from_values(k_line, sma_config)
	
	return k_line, d_line
}

