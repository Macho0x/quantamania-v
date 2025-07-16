module indicators

// vwap calculates the Volume Weighted Average Price.
// Note: VWAP is typically calculated on an intraday basis and reset at the start of each new day.
// This implementation shows a continuous calculation.
pub fn vwap(data []OHLCV) []f64 {
	if data.len == 0 {
		return []f64{}
	}

	mut vwap_values := []f64{}
	mut cumulative_pv := 0.0
	mut cumulative_volume := 0.0

	for d in data {
		typical_price := (d.high + d.low + d.close) / 3.0
		price_volume := typical_price * d.volume

		cumulative_pv += price_volume
		cumulative_volume += d.volume

		current_vwap := if cumulative_volume == 0.0 { 0.0 } else { cumulative_pv / cumulative_volume }
		vwap_values << current_vwap
	}

	return vwap_values
}

