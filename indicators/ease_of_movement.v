module indicators

// ease_of_movement calculates the Ease of Movement indicator for the given period.
// EOM measures the relationship between price and volume to identify buying/selling pressure.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: EOMConfig struct with period parameter.
//
// Returns:
//   Array of EOM values.
//   Empty array if insufficient data or invalid period.
pub fn ease_of_movement(data []OHLCV, config EOMConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return []f64{}
	}

	mut result := []f64{}
	mut eom_values := []f64{}

	// Calculate raw EOM values
	for i := 1; i < data.len; i++ {
		current := data[i]
		previous := data[i - 1]
		
		// Calculate midpoint move
		current_midpoint := (current.high + current.low) / 2.0
		previous_midpoint := (previous.high + previous.low) / 2.0
		midpoint_move := current_midpoint - previous_midpoint
		
		// Calculate box ratio (high - low)
		box_ratio := current.high - current.low
		
		// Calculate EOM
		eom_value := if box_ratio > 0.0 && current.volume > 0.0 { 
			midpoint_move / (box_ratio / current.volume) 
		} else { 
			0.0 
		}
		
		eom_values << eom_value
	}

	// Calculate smoothed EOM using simple moving average
	for i := period - 1; i < eom_values.len; i++ {
		mut sum := 0.0
		for j := 0; j < period; j++ {
			sum += eom_values[i - j]
		}
		result << sum / f64(period)
	}

	return result
} 