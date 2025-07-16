module indicators

// trix calculates the TRIX indicator.
pub fn trix(data []OHLCV, config TRIXConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	mut close_prices := []f64{}
	for d in data {
		close_prices << d.close
	}

	if close_prices.len < period * 3 {
		return []f64{}
	}

	ema_config := EMAConfig{period: period}
	ema1 := ema_from_values(close_prices, ema_config)
	ema2 := ema_from_values(ema1, ema_config)
	ema3 := ema_from_values(ema2, ema_config)

	mut trix_values := []f64{}
	for i := 1; i < ema3.len; i++ {
		prev_ema3 := ema3[i - 1]
		current_ema3 := ema3[i]
		
		trix_val := if prev_ema3 == 0.0 { 0.0 } else { (current_ema3 - prev_ema3) / prev_ema3 * 100.0 }
		trix_values << trix_val
	}

	return trix_values
}

