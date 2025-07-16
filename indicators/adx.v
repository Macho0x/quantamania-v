module indicators

// ADX calculation depends on Wilder's smoothing functions from wilders.v
// Uses: wilders_smoothing_from_values()

// adx calculates the Average Directional Index (ADX), +DI, and -DI.
pub fn adx(data []OHLCV, config ADXConfig) ([]f64, []f64, []f64) {
	validated_config := config.validate() or { return []f64{}, []f64{}, []f64{} }
	period := validated_config.period
	
	if data.len < period * 2 {
		// Not enough data to calculate ADX, which requires a smoothing of a smoothing.
		return []f64{}, []f64{}, []f64{}
	}

	// Step 1: Calculate True Range (TR), +Directional Movement (+DM), and -Directional Movement (-DM)
	mut true_ranges := []f64{}
	mut plus_dm := []f64{}
	mut minus_dm := []f64{}

	for i := 1; i < data.len; i++ {
		prev_close := data[i - 1].close
		high := data[i].high
		low := data[i].low
		prev_high := data[i - 1].high
		prev_low := data[i - 1].low

		tr1 := high - low
		tr2 := if high - prev_close > 0 { high - prev_close } else { prev_close - high }
		tr3 := if low - prev_close > 0 { low - prev_close } else { prev_close - low }
		max_tr := if tr1 > tr2 { tr1 } else { tr2 }
		tr := if max_tr > tr3 { max_tr } else { tr3 }
		true_ranges << tr

		up_move := high - prev_high
		down_move := prev_low - low

		pdm := if up_move > down_move && up_move > 0 { up_move } else { 0.0 }
		mdm := if down_move > up_move && down_move > 0 { down_move } else { 0.0 }
		plus_dm << pdm
		minus_dm << mdm
	}

	// Step 2: Smooth TR, +DM, and -DM using Wilder's Smoothing to get ATR, Smoothed +DM, and Smoothed -DM
	wilders_config := WildersConfig{period: period}
	atr := wilders_smoothing_from_values(true_ranges, wilders_config)
	smoothed_plus_dm := wilders_smoothing_from_values(plus_dm, wilders_config)
	smoothed_minus_dm := wilders_smoothing_from_values(minus_dm, wilders_config)

	// Step 3: Calculate +Directional Indicator (+DI) and -Directional Indicator (-DI)
	mut plus_di := []f64{}
	mut minus_di := []f64{}
	for i := 0; i < atr.len; i++ {
		pdi := if atr[i] == 0.0 { 0.0 } else { (smoothed_plus_dm[i] / atr[i]) * 100.0 }
		mdi := if atr[i] == 0.0 { 0.0 } else { (smoothed_minus_dm[i] / atr[i]) * 100.0 }
		plus_di << pdi
		minus_di << mdi
	}

	// Step 4: Calculate the Directional Movement Index (DX)
	mut dx_values := []f64{}
	for i := 0; i < plus_di.len; i++ {
		di_sum := plus_di[i] + minus_di[i]
		di_diff := if plus_di[i] - minus_di[i] > 0 { plus_di[i] - minus_di[i] } else { minus_di[i] - plus_di[i] }
		dx := if di_sum == 0.0 { 0.0 } else { (di_diff / di_sum) * 100.0 }
		dx_values << dx
	}

	// Step 5: Calculate the ADX by smoothing the DX values
	adx_line := wilders_smoothing_from_values(dx_values, wilders_config)

    // The DI lines need to be aligned with the ADX line.
    // The smoothing process creates a lag, so we slice the DI arrays to match the ADX length.
    dx_start_index := smoothed_plus_dm.len - adx_line.len

	final_plus_di := plus_di[dx_start_index..].clone()
	final_minus_di := minus_di[dx_start_index..].clone()

	return adx_line, final_plus_di, final_minus_di
}