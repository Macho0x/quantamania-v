module indicators

// hull_moving_average calculates the Hull Moving Average for the given period.
// HMA reduces lag while maintaining smoothness by using weighted moving averages.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: HMAConfig struct with period parameter.
//
// Returns:
//   Array of HMA values.
//   Empty array if insufficient data or invalid period.
pub fn hull_moving_average(data []OHLCV, config HMAConfig) []f64 {
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

	// Calculate WMA with period/2
	half_period := period / 2
	wma1 := weighted_moving_average(prices, half_period)
	
	// Calculate WMA with period
	wma2 := weighted_moving_average(prices, period)
	
	// Calculate raw HMA: 2 * WMA(period/2) - WMA(period)
	mut raw_hma := []f64{}
	for i := 0; i < wma1.len && i < wma2.len; i++ {
		raw_hma << 2.0 * wma1[i] - wma2[i]
	}
	
	// Apply WMA to raw HMA with sqrt(period)
	sqrt_period := int(sqrt(f64(period)))
	return weighted_moving_average(raw_hma, sqrt_period)
}

// weighted_moving_average calculates the Weighted Moving Average.
// Helper function for HMA calculation.
fn weighted_moving_average(data []f64, period int) []f64 {
	if data.len == 0 || period <= 0 || data.len < period {
		return []f64{}
	}

	mut result := []f64{}
	
	for i := period - 1; i < data.len; i++ {
		mut sum := 0.0
		mut weight_sum := 0.0
		
		for j := 0; j < period; j++ {
			weight := f64(j + 1)
			sum += data[i - j] * weight
			weight_sum += weight
		}
		
		result << sum / weight_sum
	}
	
	return result
} 