module indicators

// volume_price_trend calculates the Volume Price Trend for the given period.
// VPT is a cumulative volume-price indicator that measures buying and selling pressure.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: VPTConfig struct with period parameter.
//
// Returns:
//   Array of VPT values.
//   Empty array if insufficient data or invalid period.
pub fn volume_price_trend(data []OHLCV, config VPTConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return []f64{}
	}

	mut result := []f64{}
	mut vpt := 0.0
	
	// Calculate VPT for each bar
	for i := 1; i < data.len; i++ {
		current := data[i]
		previous := data[i - 1]
		
		// Calculate price change percentage
		price_change_pct := if previous.close > 0.0 { 
			((current.close - previous.close) / previous.close) * 100.0 
		} else { 
			0.0 
		}
		
		// Calculate VPT increment: Volume * Price Change Percentage
		vpt_increment := current.volume * price_change_pct
		vpt += vpt_increment
		
		result << vpt
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