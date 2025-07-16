module indicators

// triple_exponential_moving_average calculates the Triple Exponential Moving Average for the given period.
// TEMA further reduces lag by applying EMA three times and using a more complex formula.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: TEMAConfig struct with period parameter.
//
// Returns:
//   Array of TEMA values.
//   Empty array if insufficient data or invalid period.
pub fn triple_exponential_moving_average(data []OHLCV, config TEMAConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return []f64{}
	}

	// Use close prices for calculation
	mut prices := []f64{}
	for bar in data {
		prices << bar.close
	}

	// Calculate first EMA
	ema1 := ema(data, EMAConfig{period: period})
	
	// Calculate EMA of EMA1
	ema1_data := create_ohlcv_from_prices(ema1)
	ema2 := ema(ema1_data, EMAConfig{period: period})
	
	// Calculate EMA of EMA2
	ema2_data := create_ohlcv_from_prices(ema2)
	ema3 := ema(ema2_data, EMAConfig{period: period})
	
	// Calculate TEMA: 3 * EMA1 - 3 * EMA2 + EMA3
	mut result := []f64{}
	for i := 0; i < ema1.len && i < ema2.len && i < ema3.len; i++ {
		result << 3.0 * ema1[i] - 3.0 * ema2[i] + ema3[i]
	}
	
	return result
} 