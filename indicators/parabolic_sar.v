module indicators

// parabolic_sar calculates the Parabolic Stop and Reverse.
pub fn parabolic_sar(data []OHLCV, config ParabolicSARConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	acceleration := validated_config.acceleration
	max_acceleration := validated_config.max_acceleration
	
	if data.len < 2 {
		return []f64{}
	}

	mut sar_values := []f64{}
    sar_values << data[0].low
	mut is_rising := true
	mut ep := data[0].high // Extreme Point
	mut af := acceleration  // Acceleration Factor

	for i := 1; i < data.len; i++ {
		prev_sar := sar_values[i - 1]
		current_high := data[i].high
		current_low := data[i].low
		prev_high := data[i-1].high
		prev_low := data[i-1].low

		// Calculate current SAR
		mut current_sar := prev_sar + af * (ep - prev_sar)

		if is_rising {
			// In an uptrend, SAR should not be above the previous or current low
			sar_limit := if prev_low < current_low { prev_low } else { current_low }
			if current_sar > sar_limit {
				current_sar = sar_limit
			}

			// Check for trend reversal
			if current_low < current_sar {
				is_rising = false
				current_sar = ep // The highest high of the uptrend
				ep = current_low
				af = acceleration
			} else {
				// Continue the uptrend
				if current_high > ep {
					ep = current_high
					af = if af + acceleration < max_acceleration { af + acceleration } else { max_acceleration }
				}
			}
		} else { // is_falling
			// In a downtrend, SAR should not be below the previous or current high
			sar_limit := if prev_high > current_high { prev_high } else { current_high }
			if current_sar < sar_limit {
				current_sar = sar_limit
			}

			// Check for trend reversal
			if current_high > current_sar {
				is_rising = true
				current_sar = ep // The lowest low of the downtrend
				ep = current_high
				af = acceleration
			} else {
				// Continue the downtrend
				if current_low < ep {
					ep = current_low
					af = if af + acceleration < max_acceleration { af + acceleration } else { max_acceleration }
				}
			}
		}
		sar_values << current_sar
	}
	return sar_values
}

