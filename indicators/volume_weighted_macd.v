module indicators

// VolumeWeightedMACDResult contains MACD, signal, and histogram values
pub struct VolumeWeightedMACDResult {
pub:
	macd_line     []f64 // MACD line
	signal_line   []f64 // Signal line
	histogram     []f64 // Histogram (MACD - Signal)
}

// volume_weighted_macd calculates the Volume Weighted MACD.
// This MACD variant incorporates volume into the calculation
// for potentially more reliable signals.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: VolumeWeightedMACDConfig struct with fast, slow, and signal periods.
//
// Returns:
//   VolumeWeightedMACDResult with macd_line, signal_line, and histogram arrays.
//   Empty arrays if insufficient data or invalid parameters.
pub fn volume_weighted_macd(data []OHLCV, config VolumeWeightedMACDConfig) VolumeWeightedMACDResult {
	validated_config := config.validate() or { return VolumeWeightedMACDResult{} }
	fast_period := validated_config.fast_period
	slow_period := validated_config.slow_period
	signal_period := validated_config.signal_period
	
	if data.len < slow_period + signal_period {
		return VolumeWeightedMACDResult{}
	}

	// Calculate volume-weighted prices
	mut vw_prices := []f64{}
	for bar in data {
		typical_price := (bar.high + bar.low + bar.close) / 3.0
		vw_price := typical_price * bar.volume
		vw_prices << vw_price
	}

	// Calculate volume-weighted moving averages
	mut fast_vwma := []f64{}
	mut slow_vwma := []f64{}
	
	for i := slow_period - 1; i < data.len; i++ {
		// Fast VWMA
		mut fast_sum := 0.0
		mut fast_volume_sum := 0.0
		for j := i - (fast_period - 1); j <= i; j++ {
			typical_price := (data[j].high + data[j].low + data[j].close) / 3.0
			fast_sum += typical_price * data[j].volume
			fast_volume_sum += data[j].volume
		}
		fast_vwma_price := if fast_volume_sum > 0.0 { fast_sum / fast_volume_sum } else { data[i].close }
		fast_vwma << fast_vwma_price
		
		// Slow VWMA
		mut slow_sum := 0.0
		mut slow_volume_sum := 0.0
		for j := i - (slow_period - 1); j <= i; j++ {
			typical_price := (data[j].high + data[j].low + data[j].close) / 3.0
			slow_sum += typical_price * data[j].volume
			slow_volume_sum += data[j].volume
		}
		slow_vwma_price := if slow_volume_sum > 0.0 { slow_sum / slow_volume_sum } else { data[i].close }
		slow_vwma << slow_vwma_price
	}

	// Calculate MACD line
	mut macd_line := []f64{}
	min_len := if fast_vwma.len < slow_vwma.len { fast_vwma.len } else { slow_vwma.len }
	
	for i := 0; i < min_len; i++ {
		fast_index := fast_vwma.len - min_len + i
		slow_index := slow_vwma.len - min_len + i
		macd := fast_vwma[fast_index] - slow_vwma[slow_index]
		macd_line << macd
	}

	// Calculate signal line (EMA of MACD)
	if macd_line.len < signal_period {
		return VolumeWeightedMACDResult{}
	}

	signal_config := EMAConfig{period: signal_period}
	signal_line := indicators.ema_from_values(macd_line, signal_config)

	// Calculate histogram
	mut histogram := []f64{}
	min_signal_len := if macd_line.len < signal_line.len { macd_line.len } else { signal_line.len }
	
	macd_start := macd_line.len - min_signal_len
	signal_start := signal_line.len - min_signal_len
	
	for i := 0; i < min_signal_len; i++ {
		hist := macd_line[macd_start + i] - signal_line[signal_start + i]
		histogram << hist
	}

	return VolumeWeightedMACDResult{
		macd_line: macd_line
		signal_line: signal_line
		histogram: histogram
	}
}

// VolumeWeightedMACDConfig configuration for Volume Weighted MACD
pub struct VolumeWeightedMACDConfig {
pub:
	fast_period   int // Fast period (typically 12)
	slow_period   int // Slow period (typically 26)
	signal_period int // Signal period (typically 9)
}

// validate validates the VolumeWeightedMACDConfig
pub fn (c VolumeWeightedMACDConfig) validate() !VolumeWeightedMACDConfig {
	if c.fast_period <= 0 || c.slow_period <= 0 || c.signal_period <= 0 {
		return error('Volume Weighted MACD periods must be positive')
	}
	if c.fast_period >= c.slow_period {
		return error('Volume Weighted MACD fast period must be less than slow period')
	}
	if c.slow_period > 1000 || c.signal_period > 1000 {
		return error('Volume Weighted MACD periods too large')
	}
	return c
}
