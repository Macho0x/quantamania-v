module indicators

// stochastic_rsi calculates the Stochastic RSI indicator.
pub fn stochastic_rsi(data []OHLCV, config StochasticRSIConfig) ([]f64, []f64) {
	validated_config := config.validate() or { return []f64{}, []f64{} }
	rsi_config := RSIConfig{period: validated_config.rsi_period}
	rsi_values := rsi(data, rsi_config)
	k_period := validated_config.k_period
	d_period := validated_config.d_period

	if rsi_values.len < k_period {
		return []f64{}, []f64{}
	}

	mut stoch_rsi_k := []f64{}
	for i := k_period - 1; i < rsi_values.len; i++ {
		mut lowest := rsi_values[i - (k_period - 1)]
		mut highest := rsi_values[i - (k_period - 1)]
		for j := i - (k_period - 1); j <= i; j++ {
			if rsi_values[j] < lowest {
				lowest = rsi_values[j]
			}
			if rsi_values[j] > highest {
				highest = rsi_values[j]
			}
		}
		stoch_rsi := if highest == lowest { 0.0 } else { (rsi_values[i] - lowest) / (highest - lowest) }
		stoch_rsi_k << stoch_rsi
	}

	sma_config := SMAConfig{period: d_period}
	stoch_rsi_d := sma_from_values(stoch_rsi_k, sma_config)
	aligned_k := stoch_rsi_k[stoch_rsi_k.len - stoch_rsi_d.len..].clone()

	return aligned_k, stoch_rsi_d
}

