module indicators

// ultimate_oscillator calculates the Ultimate Oscillator.
pub fn ultimate_oscillator(data []OHLCV, config UltimateOscillatorConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period1 := validated_config.period1
	period2 := validated_config.period2
	period3 := validated_config.period3
	
	if data.len < period3 {
		return []f64{}
	}

	mut buying_pressures := []f64{}
	mut true_ranges := []f64{}

	for i := 1; i < data.len; i++ {
		close := data[i].close
		prev_close := data[i - 1].close
		high := data[i].high
		low := data[i].low

		min_low := if low < prev_close { low } else { prev_close }
		max_high := if high > prev_close { high } else { prev_close }
		
		buying_pressure := close - min_low
		true_range := max_high - min_low
		
		buying_pressures << buying_pressure
		true_ranges << true_range
	}

	mut uo_values := []f64{}
	for i := period3 - 2; i < buying_pressures.len; i++ {
		if i - (period1 - 1) < 0 || i - (period2 - 1) < 0 || i - (period3 - 1) < 0 {
			continue
		}
		mut bp_sum1 := 0.0
		mut tr_sum1 := 0.0
		for j := i - (period1 - 1); j <= i; j++ {
			bp_sum1 += buying_pressures[j]
			tr_sum1 += true_ranges[j]
		}
		avg1 := if tr_sum1 == 0.0 { 0.0 } else { bp_sum1 / tr_sum1 }

		mut bp_sum2 := 0.0
		mut tr_sum2 := 0.0
		for j := i - (period2 - 1); j <= i; j++ {
			bp_sum2 += buying_pressures[j]
			tr_sum2 += true_ranges[j]
		}
		avg2 := if tr_sum2 == 0.0 { 0.0 } else { bp_sum2 / tr_sum2 }

		mut bp_sum3 := 0.0
		mut tr_sum3 := 0.0
		for j := i - (period3 - 1); j <= i; j++ {
			bp_sum3 += buying_pressures[j]
			tr_sum3 += true_ranges[j]
		}
		avg3 := if tr_sum3 == 0.0 { 0.0 } else { bp_sum3 / tr_sum3 }

		uo := 100.0 * ((4.0 * avg1) + (2.0 * avg2) + avg3) / (4.0 + 2.0 + 1.0)
		uo_values << uo
	}

	return uo_values
}

