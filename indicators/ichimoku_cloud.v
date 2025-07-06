module indicators

// ichimoku_cloud calculates the Ichimoku Cloud components.
// It returns: Tenkan-sen, Kijun-sen, Senkou Span A, Senkou Span B, Chikou Span
pub fn ichimoku_cloud(data []OHLCV, config IchimokuConfig) ([]f64, []f64, []f64, []f64, []f64) {
	validated_config := config.validate() or { return []f64{}, []f64{}, []f64{}, []f64{}, []f64{} }
	tenkan_period := validated_config.tenkan_period
	kijun_period := validated_config.kijun_period
	senkou_b_period := validated_config.senkou_b_period
	
	if data.len < senkou_b_period {
		return []f64{}, []f64{}, []f64{}, []f64{}, []f64{}
	}

	mut tenkan_sen := []f64{}
	mut kijun_sen := []f64{}
	mut chikou_span := []f64{}

	// Calculate Tenkan-sen and Kijun-sen
	for i := 0; i < data.len; i++ {
		// Tenkan-sen (Conversion Line)
		if i >= tenkan_period - 1 {
			mut highest_high := data[i].high
			mut lowest_low := data[i].low
			for j := i - (tenkan_period - 1); j <= i; j++ {
				if data[j].high > highest_high {
					highest_high = data[j].high
				}
				if data[j].low < lowest_low {
					lowest_low = data[j].low
				}
			}
			tenkan_sen << (highest_high + lowest_low) / 2.0
		}

		// Kijun-sen (Base Line)
		if i >= kijun_period - 1 {
			mut highest_high := data[i].high
			mut lowest_low := data[i].low
			for j := i - (kijun_period - 1); j <= i; j++ {
				if data[j].high > highest_high {
					highest_high = data[j].high
				}
				if data[j].low < lowest_low {
					lowest_low = data[j].low
				}
			}
			kijun_sen << (highest_high + lowest_low) / 2.0
		}
	}

	// Align Tenkan-sen with Kijun-sen
	aligned_tenkan := tenkan_sen[kijun_period - tenkan_period..].clone()

	// Calculate Senkou Span A and B
	mut senkou_span_a := []f64{}
	mut senkou_span_b := []f64{}
	for i := 0; i < aligned_tenkan.len; i++ {
		senkou_span_a << (aligned_tenkan[i] + kijun_sen[i]) / 2.0
	}

	for i := senkou_b_period - 1; i < data.len; i++ {
		mut highest_high := data[i].high
		mut lowest_low := data[i].low
		for j := i - (senkou_b_period - 1); j <= i; j++ {
			if data[j].high > highest_high {
				highest_high = data[j].high
			}
			if data[j].low < lowest_low {
				lowest_low = data[j].low
			}
		}
		senkou_span_b << (highest_high + lowest_low) / 2.0
	}

	// Calculate Chikou Span (Lagging Span)
	for d in data {
		chikou_span << d.close
	}

	return tenkan_sen, kijun_sen, senkou_span_a, senkou_span_b, chikou_span
}

