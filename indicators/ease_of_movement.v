module indicators

// ease_of_movement calculates the Ease of Movement (EMV) indicator.
// EMV measures how easily prices move up or down based on volume.
// High values indicate easy upward movement, low values indicate easy downward movement.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: EMVConfig struct with period parameter.
//
// Returns:
//   Array of EMV values.
//   Empty array if insufficient data or invalid parameters.
pub fn ease_of_movement(data []OHLCV, config EMVConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len < period + 1 {
		return []f64{}
	}

	mut raw_emv := []f64{}

	// Calculate raw EMV values
	for i := 1; i < data.len; i++ {
		prev_bar := data[i-1]
		current_bar := data[i]
		
		// Calculate distance moved
		distance_moved := ((current_bar.high + current_bar.low) / 2.0) - 
						  ((prev_bar.high + prev_bar.low) / 2.0)
		
		// Calculate box ratio
		volume := current_bar.volume
		high_low_range := current_bar.high - current_bar.low
		
		mut box_ratio := 0.0
		if volume > 0.0 && high_low_range > 0.0 {
			box_ratio = volume / (10000.0 * high_low_range)
		}
		
		// Calculate EMV
		emv := if box_ratio > 0.0 { distance_moved / box_ratio } else { 0.0 }
		raw_emv << emv
	}

	// Apply SMA smoothing
	if period <= 1 {
		return raw_emv
	}

	mut smoothed_emv := []f64{}
	
	for i := period - 1; i < raw_emv.len; i++ {
		mut sum := 0.0
		for j := 0; j < period; j++ {
			sum += raw_emv[i - j]
		}
		smoothed_emv << sum / f64(period)
	}

	return smoothed_emv
}

// EMVConfig configuration for Ease of Movement
pub struct EMVConfig {
pub:
	period int // Period for SMA smoothing (typically 14)
}

// validate validates the EMVConfig
pub fn (c EMVConfig) validate() !EMVConfig {
	if c.period <= 0 {
		return error('Ease of Movement period must be positive')
	}
	if c.period > 1000 {
		return error('Ease of Movement period too large')
	}
	return c
}