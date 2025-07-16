module indicators

// VolumeProfileResult contains volume profile data
pub struct VolumeProfileResult {
pub:
	price_levels []f64    // Price levels
	volume_at_price []f64 // Volume at each price level
	value_area_high f64   // Value area high
	value_area_low f64    // Value area low
	point_of_control f64  // Price with highest volume
	total_volume f64      // Total volume in profile
}

// volume_profile calculates a basic volume profile.
// Volume Profile shows volume traded at specific price levels.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: VolumeProfileConfig struct with parameters.
//
// Returns:
//   VolumeProfileResult with price levels and corresponding volumes.
//   Empty result if insufficient data or invalid parameters.
pub fn volume_profile(data []OHLCV, config VolumeProfileConfig) VolumeProfileResult {
	validated_config := config.validate() or { return VolumeProfileResult{} }
	
	if data.len == 0 {
		return VolumeProfileResult{}
	}

	// Find price range
	mut min_price := data[0].low
	mut max_price := data[0].high
	
	for bar in data {
		if bar.low < min_price {
			min_price = bar.low
		}
		if bar.high > max_price {
			max_price = bar.high
		}
	}
	
	if min_price >= max_price {
		return VolumeProfileResult{}
	}

	// Calculate price levels and bin size
	price_range := max_price - min_price
	num_bins := validated_config.num_bins
	bin_size := price_range / f64(num_bins)
	
	mut price_levels := []f64{}
	mut volume_at_price := []f64{}
	
	// Initialize arrays
	for i := 0; i < num_bins; i++ {
		price_level := min_price + (bin_size * f64(i)) + (bin_size / 2.0)
		price_levels << price_level
		volume_at_price << 0.0
	}
	
	mut total_volume := 0.0
	
	// Distribute volume across price levels
	for bar in data {
		// For each bar, distribute volume across the price range
		bar_range := bar.high - bar.low
		if bar_range <= 0.0 {
			// All volume at close price
			close_bin := int(((bar.close - min_price) / price_range) * f64(num_bins))
			if close_bin >= 0 && close_bin < num_bins {
				volume_at_price[close_bin] += bar.volume
				total_volume += bar.volume
			}
		} else {
			// Distribute volume proportionally across price range
			start_bin := int(((bar.low - min_price) / price_range) * f64(num_bins))
			end_bin := int(((bar.high - min_price) / price_range) * f64(num_bins))
			
			mut start_bin_mut := start_bin
			mut end_bin_mut := end_bin
			start_bin_mut = if start_bin_mut < 0 { 0 } else { start_bin_mut }
			end_bin_mut = if end_bin_mut >= num_bins { num_bins - 1 } else { end_bin_mut }
			
			if start_bin_mut == end_bin_mut {
				// All volume in single bin
				volume_at_price[start_bin_mut] += bar.volume
				total_volume += bar.volume
			} else {
				// Distribute volume across bins
				bins_covered := end_bin_mut - start_bin_mut + 1
				volume_per_bin := bar.volume / f64(bins_covered)
				
				for bin := start_bin_mut; bin <= end_bin_mut; bin++ {
					if bin >= 0 && bin < num_bins {
						volume_at_price[bin] += volume_per_bin
						total_volume += volume_per_bin
					}
				}
			}
		}
	}
	
	// Find point of control (highest volume)
	mut max_volume := 0.0
	mut point_of_control := 0.0
	for i := 0; i < num_bins; i++ {
		if volume_at_price[i] > max_volume {
			max_volume = volume_at_price[i]
			point_of_control = price_levels[i]
		}
	}
	
	// Calculate value area (70% of volume around POC)
	value_area_volume := total_volume * 0.7
	mut cumulative_volume := 0.0
	mut value_area_low := min_price
	mut value_area_high := max_price
	
	// Find value area boundaries
	mut poc_index := 0
	for i := 0; i < num_bins; i++ {
		if price_levels[i] == point_of_control {
			poc_index = i
			break
		}
	}
	
	// Expand from POC to find value area
	mut left := poc_index
	mut right := poc_index
	
	for cumulative_volume < value_area_volume && (left > 0 || right < num_bins - 1) {
		if left > 0 && (right >= num_bins - 1 || 
			volume_at_price[left-1] >= volume_at_price[right+1]) {
			left--
			cumulative_volume += volume_at_price[left]
		} else if right < num_bins - 1 {
			right++
			cumulative_volume += volume_at_price[right]
		} else {
			break
		}
	}
	
	if left >= 0 && right < num_bins {
		value_area_low = price_levels[left]
		value_area_high = price_levels[right]
	}
	
	return VolumeProfileResult{
		price_levels: price_levels
		volume_at_price: volume_at_price
		value_area_high: value_area_high
		value_area_low: value_area_low
		point_of_control: point_of_control
		total_volume: total_volume
	}
}

// VolumeProfileConfig configuration for Volume Profile
pub struct VolumeProfileConfig {
pub:
	num_bins int // Number of price bins/levels (typically 50-100)
}

// validate validates the VolumeProfileConfig
pub fn (c VolumeProfileConfig) validate() !VolumeProfileConfig {
    if c.num_bins <= 0 {
        return error('Volume Profile num_bins must be positive')
    }
    if c.num_bins < 10 {
        return error('Volume Profile num_bins should be at least 10')
    }
    if c.num_bins > 1000 {
        return error('Volume Profile num_bins too large')
    }
    return c
}