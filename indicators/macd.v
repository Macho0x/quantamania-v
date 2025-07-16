module indicators

// macd calculates the Moving Average Convergence Divergence.
// It returns the MACD line, the signal line, and the histogram.
pub fn macd(data []OHLCV, config MACDConfig) ([]f64, []f64, []f64) {
	validated_config := config.validate() or { return []f64{}, []f64{}, []f64{} }
	short_period := validated_config.short_period
	long_period := validated_config.long_period
	signal_period := validated_config.signal_period
	
	mut close_prices := []f64{}
	for d in data {
		close_prices << d.close
	}

	if close_prices.len < long_period {
		return []f64{}, []f64{}, []f64{}
	}

	short_ema_config := EMAConfig{period: short_period}
	long_ema_config := EMAConfig{period: long_period}
	signal_ema_config := EMAConfig{period: signal_period}
	
	ema_short := ema(data, short_ema_config)
	ema_long := ema(data, long_ema_config)

	// Align the two EMA series. ema_long will be shorter.
	short_ema_aligned := ema_short[long_period-short_period..]

	mut macd_line := []f64{}
	for i := 0; i < ema_long.len; i++ {
		macd_line << short_ema_aligned[i] - ema_long[i]
	}

	if macd_line.len < signal_period {
		return []f64{}, []f64{}, []f64{}
	}

	signal_line := ema_from_values(macd_line, signal_ema_config)

	// Align MACD line with signal line
	macd_line_aligned := macd_line[macd_line.len-signal_line.len..].clone()

	mut histogram := []f64{}
	for i := 0; i < signal_line.len; i++ {
		histogram << macd_line_aligned[i] - signal_line[i]
	}

	return macd_line_aligned, signal_line, histogram
}

