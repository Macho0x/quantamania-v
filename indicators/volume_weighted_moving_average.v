module indicators

// volume_weighted_moving_average calculates the Volume Weighted Moving Average for the given period.
// VWMA gives more weight to periods with higher volume.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: VWMAConfig struct with period parameter.
//
// Returns:
//   Array of VWMA values.
//   Empty array if insufficient data or invalid period.
pub fn volume_weighted_moving_average(data []OHLCV, config VWMAConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return []f64{}
	}

	mut result := []f64{}
	
	for i := period - 1; i < data.len; i++ {
		mut price_volume_sum := 0.0
		mut volume_sum := 0.0
		
		// Calculate weighted sum for the period
		for j := 0; j < period; j++ {
			bar := data[i - j]
			price_volume_sum += bar.close * bar.volume
			volume_sum += bar.volume
		}
		
		// Calculate VWMA
		if volume_sum > 0.0 {
			result << price_volume_sum / volume_sum
		} else {
			// Fallback to simple average if no volume
			mut price_sum := 0.0
			for j := 0; j < period; j++ {
				price_sum += data[i - j].close
			}
			result << price_sum / f64(period)
		}
	}
	
	return result
} 