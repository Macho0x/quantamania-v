module indicators

// force_index calculates the Force Index indicator.
// The Force Index measures the force behind price movements
// by combining price change and volume.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: ForceIndexConfig struct with period parameter.
//
// Returns:
//   Array of Force Index values.
//   Empty array if insufficient data or invalid parameters.
pub fn force_index(data []OHLCV, config ForceIndexConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len < period + 1 {
		return []f64{}
	}

	mut raw_force := []f64{}
	
	// Calculate raw Force Index values
	for i := 1; i < data.len; i++ {
		price_change := data[i].close - data[i-1].close
		force := price_change * data[i].volume
		raw_force << force
	}

	// Apply EMA smoothing to raw Force Index
	if period == 1 {
		return raw_force
	}

	// Create OHLCV data for EMA calculation
	mut ema_data := []OHLCV{}
	for i := 0; i < raw_force.len; i++ {
		ema_data << OHLCV{
			open: raw_force[i]
			high: raw_force[i]
			low: raw_force[i]
			close: raw_force[i]
			volume: 0.0
		}
	}

	ema_config := EMAConfig{period: period}
	smoothed_force := ema(ema_data, ema_config)
	
	return smoothed_force
}

// ForceIndexConfig configuration for Force Index
pub struct ForceIndexConfig {
pub:
	period int // Period for EMA smoothing (typically 2 or 13)
}

// validate validates the ForceIndexConfig
pub fn (c ForceIndexConfig) validate() !ForceIndexConfig {
	if c.period <= 0 {
		return error('Force Index period must be positive')
	}
	if c.period > 1000 {
		return error('Force Index period too large')
	}
	return c
}