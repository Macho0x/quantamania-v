module indicators

// cci calculates the Commodity Channel Index.
pub fn cci(data []OHLCV, config CCIConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len < period {
		return []f64{}
	}

	mut typical_prices := []f64{}
	for d in data {
		typical_prices << (d.high + d.low + d.close) / 3.0
	}

	sma_config := SMAConfig{period: period}
	typical_price_sma := sma(data, sma_config)

	mut mean_deviations := []f64{}
	for i := period - 1; i < typical_prices.len; i++ {
		sma_val := typical_price_sma[i - (period - 1)]
		mut deviation_sum := 0.0
		for j := i - (period - 1); j <= i; j++ {
			deviation_sum += if typical_prices[j] - sma_val > 0 { typical_prices[j] - sma_val } else { sma_val - typical_prices[j] }
		}
		mean_deviations << deviation_sum / f64(period)
	}

	mut cci_values := []f64{}
	for i := 0; i < mean_deviations.len; i++ {
		sma_val := typical_price_sma[i]
		mean_dev := mean_deviations[i]
		// The index for typical_prices needs to be offset by the period
		tp_index := i + (period - 1)
		
		cci_val := if mean_dev == 0.0 { 0.0 } else { (typical_prices[tp_index] - sma_val) / (0.015 * mean_dev) }
		cci_values << cci_val
	}

	return cci_values
}
