module indicators

// donchian_channels calculates the Upper, Middle, and Lower Donchian Channels.
pub fn donchian_channels(data []OHLCV, config DonchianConfig) ([]f64, []f64, []f64) {
	validated_config := config.validate() or { return []f64{}, []f64{}, []f64{} }
	period := validated_config.period
	
	if data.len < period {
		return []f64{}, []f64{}, []f64{}
	}

	mut upper_band := []f64{}
	mut lower_band := []f64{}
	mut middle_band := []f64{}

	for i := period - 1; i < data.len; i++ {
		mut highest_high := data[i - (period - 1)].high
		mut lowest_low := data[i - (period - 1)].low

		for j := i - (period - 1); j <= i; j++ {
			if data[j].high > highest_high {
				highest_high = data[j].high
			}
			if data[j].low < lowest_low {
				lowest_low = data[j].low
			}
		}
		
		upper_band << highest_high
		lower_band << lowest_low
		middle_band << (highest_high + lowest_low) / 2.0
	}

	return upper_band, middle_band, lower_band
}

