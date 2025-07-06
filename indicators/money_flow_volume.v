module indicators

// money_flow_volume calculates the Money Flow Volume for the given period.
// MFV is a volume-weighted momentum indicator that measures buying and selling pressure.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: MFVConfig struct with period parameter.
//
// Returns:
//   Array of MFV values.
//   Empty array if insufficient data or invalid period.
pub fn money_flow_volume(data []OHLCV, config MFVConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return []f64{}
	}

	mut result := []f64{}
	mut mfv_values := []f64{}
	
	// Calculate MFV for each bar
	for i := 1; i < data.len; i++ {
		current := data[i]
		previous := data[i - 1]
		
		// Calculate typical price
		typical_price := current.typical_price()
		prev_typical_price := previous.typical_price()
		
		// Calculate money flow multiplier
		money_flow_multiplier := if typical_price > prev_typical_price { 
			1.0 
		} else if typical_price < prev_typical_price { 
			-1.0 
		} else { 
			0.0 
		}
		
		// Calculate money flow volume
		money_flow_volume := money_flow_multiplier * current.volume
		mfv_values << money_flow_volume
	}
	
	// Calculate cumulative MFV with smoothing
	for i := 0; i < mfv_values.len; i++ {
		_ := mfv_values[i]
		
		// Apply smoothing if we have enough data
		if i >= period - 1 {
			// Calculate average MFV over the period
			mut sum := 0.0
			for j := 0; j < period; j++ {
				sum += mfv_values[i - j]
			}
			result << sum / f64(period)
		}
	}
	
	return result
} 