module indicators

// awesome_oscillator calculates the AO.
pub fn awesome_oscillator(data []OHLCV, config AwesomeOscillatorConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	short_period := validated_config.short_period
	long_period := validated_config.long_period
	
	if data.len < long_period {
		return []f64{}
	}

	mut midpoints := []f64{}
	for d in data {
		midpoints << (d.high + d.low) / 2.0
	}

	short_sma_config := SMAConfig{period: short_period}
	long_sma_config := SMAConfig{period: long_period}
	
	sma_short := sma_from_values(midpoints, short_sma_config)
	sma_long := sma_from_values(midpoints, long_sma_config)

	// Align the two SMA series. sma_long will be shorter.
	sma_short_aligned := sma_short[long_period - short_period..]

	mut ao_values := []f64{}
	for i := 0; i < sma_long.len; i++ {
		ao_values << sma_short_aligned[i] - sma_long[i]
	}

	return ao_values
}

