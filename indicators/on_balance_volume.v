module indicators

// on_balance_volume calculates the OBV.
pub fn on_balance_volume(data []OHLCV) []f64 {
	if data.len == 0 {
		return []f64{}
	}

	mut obv_values := []f64{}
    obv_values << 0.0
	for i := 1; i < data.len; i++ {
		prev_obv := obv_values[i - 1]
		current_volume := data[i].volume
		
		if data[i].close > data[i - 1].close {
			obv_values << prev_obv + current_volume
		} else if data[i].close < data[i - 1].close {
			obv_values << prev_obv - current_volume
		} else {
			obv_values << prev_obv
		}
	}
	return obv_values
}

