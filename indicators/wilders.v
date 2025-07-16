module indicators

// wilders_smoothing calculates the Wilder's Smoothing Average.
// This is a type of Exponential Moving Average with a specific smoothing factor.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: WildersConfig struct with period parameter.
//
// Returns:
//   Array of smoothed values.
//   Empty array if insufficient data or invalid period.
pub fn wilders_smoothing(data []OHLCV, config WildersConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	if data.len == 0 || period <= 0 || period > data.len {
		return []f64{}
	}

	mut result := []f64{}
	
	// Initial SMA for the first value
	mut sum := 0.0
	for i := 0; i < period; i++ {
		sum += data[i].close
	}
	initial_value := sum / f64(period)
	result << initial_value

	// Calculate subsequent values
	for i := period; i < data.len; i++ {
		smoothed_value := (result[result.len - 1] * f64(period - 1) + data[i].close) / f64(period)
		result << smoothed_value
	}

	return result
}

// wilders_smoothing_from_values calculates Wilder's Smoothing Average from a simple array of values.
// Helper function for other indicators that need Wilder's smoothing on calculated values.
//
// Parameters:
//   values: Array of f64 values.
//   config: WildersConfig struct with period parameter.
//
// Returns:
//   Array of smoothed values.
//   Empty array if insufficient data or invalid period.
pub fn wilders_smoothing_from_values(values []f64, config WildersConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	if values.len == 0 || period <= 0 || period > values.len {
		return []f64{}
	}

	mut result := []f64{}
	
	// Initial SMA for the first value
	mut sum := 0.0
	for i := 0; i < period; i++ {
		sum += values[i]
	}
	initial_value := sum / f64(period)
	result << initial_value

	// Calculate subsequent values
	for i := period; i < values.len; i++ {
		smoothed_value := (result[result.len - 1] * f64(period - 1) + values[i]) / f64(period)
		result << smoothed_value
	}

	return result
}
