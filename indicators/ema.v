module indicators

// ema calculates the Exponential Moving Average for the given period.
// Uses the close price from OHLCV data.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: EMAConfig struct with period parameter.
//
// Returns:
//   Array of EMA values.
//   Empty array if insufficient data or invalid period.
pub fn ema(data []OHLCV, config EMAConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || period > data.len {
		return []f64{}
	}

	mut result := []f64{}
	multiplier := 2.0 / (f64(period) + 1.0)

	// Calculate initial SMA for the first EMA value
	mut sum := 0.0
	for i := 0; i < period; i++ {
		sum += data[i].close
	}
	initial_ema := sum / f64(period)
	result << initial_ema

	// Calculate subsequent EMA values
	for i := period; i < data.len; i++ {
		ema_value := (data[i].close - result[result.len - 1]) * multiplier + result[result.len - 1]
		result << ema_value
	}

	return result
}

// ema_from_values calculates EMA from a simple array of values.
// Helper function for other indicators that need EMA on calculated values.
//
// Parameters:
//   values: Array of f64 values.
//   config: EMAConfig struct with period parameter.
//
// Returns:
//   Array of EMA values.
//   Empty array if insufficient data or invalid period.
pub fn ema_from_values(values []f64, config EMAConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if values.len == 0 || period <= 0 || period > values.len {
		return []f64{}
	}

	mut result := []f64{}
	multiplier := 2.0 / (f64(period) + 1.0)

	// Calculate initial SMA for the first EMA value
	mut sum := 0.0
	for i := 0; i < period; i++ {
		sum += values[i]
	}
	initial_ema := sum / f64(period)
	result << initial_ema

	// Calculate subsequent EMA values
	for i := period; i < values.len; i++ {
		ema_value := (values[i] - result[result.len - 1]) * multiplier + result[result.len - 1]
		result << ema_value
	}

	return result
}
