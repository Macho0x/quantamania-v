module indicators

// sma calculates the Simple Moving Average for the given period
// Uses the close price from OHLCV data
// 
// Parameters:
//   data: Array of OHLCV price data
//   config: SMAConfig struct with period parameter
//
// Returns:
//   Array of SMA values, starting from index (period-1)
//   Empty array if insufficient data or invalid period
pub fn sma(data []OHLCV, config SMAConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || period > data.len {
		return []f64{}
	}

	mut result := []f64{}
	
	// Calculate SMA for each valid position
	for i := period - 1; i < data.len; i++ {
		mut sum := 0.0
		// Sum the close prices for the period
		for j := 0; j < period; j++ {
			sum += data[i - j].close
		}
		result << sum / f64(period)
	}
	
	return result
}

// sma_from_values calculates SMA from a simple array of values
// Helper function for other indicators that need SMA on calculated values
pub fn sma_from_values(values []f64, config SMAConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if values.len == 0 || period <= 0 || period > values.len {
		return []f64{}
	}

	mut result := []f64{}
	
	for i := period - 1; i < values.len; i++ {
		mut sum := 0.0
		for j := 0; j < period; j++ {
			sum += values[i - j]
		}
		result << sum / f64(period)
	}
	
	return result
}
