module indicators

// ulcer_index calculates the Ulcer Index for the given period.
// Ulcer Index measures downside volatility and drawdown risk.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: UlcerIndexConfig struct with period parameter.
//
// Returns:
//   Array of Ulcer Index values.
//   Empty array if insufficient data or invalid period.
pub fn ulcer_index(data []OHLCV, config UlcerIndexConfig) []f64 {
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

	mut result := []f64{}
	
	for i := period - 1; i < prices.len; i++ {
		// Find the highest high in the period
		mut highest_high := prices[i]
		for j := 0; j < period; j++ {
			if prices[i - j] > highest_high {
				highest_high = prices[i - j]
			}
		}
		
		// Calculate percentage drawdowns
		mut sum_squared_drawdowns := 0.0
		for j := 0; j < period; j++ {
			current_price := prices[i - j]
			if highest_high > 0.0 {
				drawdown := (current_price - highest_high) / highest_high
				// Only consider negative drawdowns (losses)
				if drawdown < 0.0 {
					sum_squared_drawdowns += drawdown * drawdown
				}
			}
		}
		
		// Calculate Ulcer Index: sqrt(average of squared drawdowns)
		ulcer_value := sqrt(sum_squared_drawdowns / f64(period))
		result << ulcer_value
	}
	
	return result
} 