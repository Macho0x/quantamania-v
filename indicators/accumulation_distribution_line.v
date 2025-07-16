module indicators

// accumulation_distribution_line calculates the A/D Line.
pub fn accumulation_distribution_line(data []OHLCV) []f64 {
	if data.len == 0 {
		return []f64{}
	}

	mut adl_values := []f64{}
	mut cumulative_adl := 0.0

	for d in data {
		high, low, close, volume := d.high, d.low, d.close, d.volume

		// Calculate Money Flow Multiplier
		money_flow_multiplier := if high == low { 0.0 } else { ((close - low) - (high - close)) / (high - low) }
		
		// Calculate Money Flow Volume
		money_flow_volume := money_flow_multiplier * volume
		
		cumulative_adl += money_flow_volume
		adl_values << cumulative_adl
	}

	return adl_values
}

