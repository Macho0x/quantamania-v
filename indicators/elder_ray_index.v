module indicators

// ElderRayResult contains the Bull Power and Bear Power values
pub struct ElderRayResult {
pub:
	bull_power []f64 // Bull Power (High - EMA)
	bear_power []f64 // Bear Power (Low - EMA)
}

// elder_ray_index calculates the Elder Ray Index (Bull Power and Bear Power).
// The Elder Ray Index measures buying and selling pressure by comparing
// high/low prices to an exponential moving average.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: ElderRayConfig struct with period parameter.
//
// Returns:
//   ElderRayResult with bull_power and bear_power arrays.
//   Empty arrays if insufficient data or invalid parameters.
pub fn elder_ray_index(data []OHLCV, config ElderRayConfig) ElderRayResult {
	validated_config := config.validate() or { return ElderRayResult{} }
	period := validated_config.period
	
	if data.len < period {
		return ElderRayResult{}
	}

	// Calculate EMA of closing prices
	ema_config := EMAConfig{period: period}
	ema_values := ema(data, ema_config)
	
	if ema_values.len == 0 {
		return ElderRayResult{}
	}

	mut bull_power := []f64{}
	mut bear_power := []f64{}
	
	// Align EMA values with original data
	start_index := data.len - ema_values.len
	
	for i := 0; i < ema_values.len; i++ {
		data_index := start_index + i
		bull := data[data_index].high - ema_values[i]
		bear := data[data_index].low - ema_values[i]
		
		bull_power << bull
		bear_power << bear
	}

	return ElderRayResult{
		bull_power: bull_power
		bear_power: bear_power
	}
}

// ElderRayConfig configuration for Elder Ray Index
pub struct ElderRayConfig {
pub:
	period int // Period for EMA calculation (typically 13)
}

// validate validates the ElderRayConfig
pub fn (c ElderRayConfig) validate() !ElderRayConfig {
	if c.period <= 0 {
		return error('Elder Ray period must be positive')
	}
	if c.period > 1000 {
		return error('Elder Ray period too large')
	}
	return c
}