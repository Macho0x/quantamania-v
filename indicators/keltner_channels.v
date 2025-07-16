module indicators

// keltner_channels calculates the Upper, Middle, and Lower Keltner Channels.
pub fn keltner_channels(data []OHLCV, config KeltnerConfig) ([]f64, []f64, []f64) {
	validated_config := config.validate() or { return []f64{}, []f64{}, []f64{} }
	period := validated_config.period
	atr_multiplier := validated_config.atr_multiplier
	
	if data.len < period {
		return []f64{}, []f64{}, []f64{}
	}

	mut typical_prices := []f64{}
	for d in data {
		typical_prices << (d.high + d.low + d.close) / 3.0
	}

	ema_config := EMAConfig{period: period}
	middle_band := ema_from_values(typical_prices, ema_config)
	atr_config := ATRConfig{period: period}
	atr := average_true_range(data, atr_config)

	// Align the bands
	middle_band_aligned := middle_band[middle_band.len - atr.len..]

	mut upper_band := []f64{}
	mut lower_band := []f64{}

	for i := 0; i < atr.len; i++ {
		upper_band << middle_band_aligned[i] + (atr[i] * atr_multiplier)
		lower_band << middle_band_aligned[i] - (atr[i] * atr_multiplier)
	}

	return upper_band, middle_band_aligned, lower_band
}

