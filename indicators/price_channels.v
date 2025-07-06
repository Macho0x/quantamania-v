module indicators

// PriceChannelsResult contains the price channel levels
pub struct PriceChannelsResult {
pub:
	upper_channel []f64 // Upper channel (resistance)
	lower_channel []f64 // Lower channel (support)
	midline       []f64 // Midline (average of upper and lower)
}

// price_channels calculates the Price Channels for the given period.
// Price Channels are dynamic support and resistance levels based on highs and lows.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: PriceChannelsConfig struct with period parameter.
//
// Returns:
//   PriceChannelsResult with upper, lower, and midline channel arrays.
//   Empty arrays if insufficient data or invalid period.
pub fn price_channels(data []OHLCV, config PriceChannelsConfig) PriceChannelsResult {
	validated_config := config.validate() or { return PriceChannelsResult{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return PriceChannelsResult{}
	}

	mut upper_channel := []f64{}
	mut lower_channel := []f64{}
	mut midline := []f64{}
	
	// Calculate price channels for each bar
	for i := period - 1; i < data.len; i++ {
		// Find highest high and lowest low in the period
		mut highest_high := data[i].high
		mut lowest_low := data[i].low
		
		for j := 0; j < period; j++ {
			bar := data[i - j]
			if bar.high > highest_high {
				highest_high = bar.high
			}
			if bar.low < lowest_low {
				lowest_low = bar.low
			}
		}
		
		// Calculate channel levels
		upper_channel << highest_high
		lower_channel << lowest_low
		midline << (highest_high + lowest_low) / 2.0
	}
	
	return PriceChannelsResult{
		upper_channel: upper_channel
		lower_channel: lower_channel
		midline: midline
	}
} 