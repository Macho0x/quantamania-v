module indicators

// williams_percent_r calculates the Williams %R indicator.
pub fn williams_percent_r(data []OHLCV, config WilliamsRConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len < period {
		return []f64{}
	}

	mut result := []f64{}
	for i := period - 1; i < data.len; i++ {
		current_close := data[i].close
		mut lowest_low := data[i - (period - 1)].low
		mut highest_high := data[i - (period - 1)].high

		for j := i - (period - 1); j <= i; j++ {
			if data[j].low < lowest_low {
				lowest_low = data[j].low
			}
			if data[j].high > highest_high {
				highest_high = data[j].high
			}
		}

		percent_r := if highest_high == lowest_low { -100.0 } else { ((highest_high - current_close) / (highest_high - lowest_low)) * -100.0 }
		result << percent_r
	}
	return result
}

