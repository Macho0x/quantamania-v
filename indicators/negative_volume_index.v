module indicators

// negative_volume_index calculates the Negative Volume Index.
// NVI focuses on days when volume decreases, assuming smart money is active on quiet days.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: NVIConfig struct with period parameter (used for smoothing).
//
// Returns:
//   Array of NVI values.
//   Empty array if insufficient data or invalid period.
pub fn negative_volume_index(data []OHLCV, config NVIConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < 2 {
		return []f64{}
	}

	mut result := []f64{}
	mut nvi := 1000.0 // Starting value
	
	// Add initial value to result
	result << nvi
	
	// Calculate NVI for each bar
	for i := 1; i < data.len; i++ {
		current := data[i]
		previous := data[i - 1]
		
		// Only calculate NVI when current volume is less than previous volume
		if current.volume < previous.volume {
			// Calculate percentage price change
			price_change_pct := if previous.close > 0.0 { 
				((current.close - previous.close) / previous.close) * 100.0 
			} else { 
				0.0 
			}
			
			// Update NVI: NVI = Previous NVI * (1 + Price Change Percentage / 100)
			nvi = nvi * (1.0 + price_change_pct / 100.0)
		}
		// If volume increases or stays the same, NVI remains unchanged
		
		result << nvi
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