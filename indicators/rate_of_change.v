module indicators

// rate_of_change calculates the Rate of Change (ROC).
pub fn rate_of_change(data []OHLCV, config ROCConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	mut close_prices := []f64{}
	for d in data {
		close_prices << d.close
	}

	if close_prices.len < period {
		return []f64{}
	}

	mut roc_values := []f64{}
	for i := period; i < close_prices.len; i++ {
		prev_price := close_prices[i - period]
		current_price := close_prices[i]
		
		roc_val := if prev_price == 0.0 { 0.0 } else { (current_price - prev_price) / prev_price * 100.0 }
		roc_values << roc_val
	}

	return roc_values
}
