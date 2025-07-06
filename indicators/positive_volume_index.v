module indicators

// positive_volume_index calculates the Positive Volume Index.
// PVI focuses on days when volume increases, assuming crowd behavior on active days.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: PVIConfig struct with period parameter (used for smoothing).
//
// Returns:
//   Array of PVI values.
//   Empty array if insufficient data or invalid period.
pub fn positive_volume_index(data []OHLCV, config PVIConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < 2 {
		return []f64{}
	}

	mut result := []f64{}
	mut pvi := 1000.0 // Starting value
	
	// Add initial value to result
	result << pvi
	
	// Calculate PVI for each bar
	for i := 1; i < data.len; i++ {
		current := data[i]
		previous := data[i - 1]
		
		// Only calculate PVI when current volume is greater than previous volume
		if current.volume > previous.volume {
			// Calculate percentage price change
			price_change_pct := if previous.close > 0.0 { 
				((current.close - previous.close) / previous.close) * 100.0 
			} else { 
				0.0 
			}
			
			// Update PVI: PVI = Previous PVI * (1 + Price Change Percentage / 100)
			pvi = pvi * (1.0 + price_change_pct / 100.0)
		}
		// If volume decreases or stays the same, PVI remains unchanged
		
		result << pvi
	}
	
	// Apply smoothing if period > 1
	if period > 1 {
		mut smoothed_result := []f64{}
		for i := period - 1; i < result.len; i++ {
			mut sum := 0.0
			for j := 0; j < period; j++ {
				sum += result[i - j]
			}
			smoothed_result << sum / f64(period)
		}
		return smoothed_result
	}
	
	return result
} 