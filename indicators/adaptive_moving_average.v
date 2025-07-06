module indicators

// adaptive_moving_average calculates the Adaptive Moving Average.
// AMA adapts to market volatility by changing its smoothing factor.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: AMAConfig struct with fast_period and slow_period parameters.
//
// Returns:
//   Array of AMA values.
//   Empty array if insufficient data or invalid parameters.
pub fn adaptive_moving_average(data []OHLCV, config AMAConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	fast_period := validated_config.fast_period
	slow_period := validated_config.slow_period
	
	if data.len == 0 || data.len < slow_period {
		return []f64{}
	}

	// Use close prices for calculation
	mut prices := []f64{}
	for bar in data {
		prices << bar.close
	}

	mut result := []f64{}
	
	// Calculate initial AMA value (SMA of first slow_period values)
	mut ama := 0.0
	for i := 0; i < slow_period; i++ {
		ama += prices[i]
	}
	ama /= f64(slow_period)
	result << ama
	
	// Calculate fast and slow smoothing factors
	fast_sf := 2.0 / (f64(fast_period) + 1.0)
	slow_sf := 2.0 / (f64(slow_period) + 1.0)
	
	// Calculate AMA for remaining data points
	for i := slow_period; i < prices.len; i++ {
		// Calculate direction (price change over slow_period)
		direction := prices[i] - prices[i - slow_period]
		
		// Calculate volatility (sum of absolute price changes over slow_period)
		mut volatility := 0.0
		for j := 0; j < slow_period; j++ {
			volatility += if prices[i - j] > prices[i - j - 1] { 
				prices[i - j] - prices[i - j - 1] 
			} else { 
				prices[i - j - 1] - prices[i - j] 
			}
		}
		
		// Calculate efficiency ratio
		efficiency_ratio := if volatility > 0.0 { direction / volatility } else { 0.0 }
		
		// Calculate adaptive smoothing factor
		sf := efficiency_ratio * (fast_sf - slow_sf) + slow_sf
		sf_squared := sf * sf
		
		// Calculate AMA
		ama = ama + sf_squared * (prices[i] - ama)
		result << ama
	}
	
	return result
} 