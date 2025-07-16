module indicators
import math

// KlingerOscillatorResult contains KVO and signal line values
pub struct KlingerOscillatorResult {
pub:
	kvo_line   []f64 // Klinger Volume Oscillator line
	signal_line []f64 // Signal line (EMA of KVO)
}

// klinger_oscillator calculates the Klinger Volume Oscillator.
// The Klinger Oscillator measures long-term money flow trends
// while remaining sensitive to short-term price movements.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: KlingerConfig struct with parameters.
//
// Returns:
//   KlingerOscillatorResult with kvo_line and signal_line arrays.
//   Empty arrays if insufficient data or invalid parameters.
pub fn klinger_oscillator(data []OHLCV, config KlingerConfig) KlingerOscillatorResult {
	validated_config := config.validate() or { return KlingerOscillatorResult{} }
	short_period := validated_config.short_period
	long_period := validated_config.long_period
	signal_period := validated_config.signal_period
	
	min_required := long_period + signal_period
	if data.len < min_required {
		return KlingerOscillatorResult{}
	}

	mut volume_force := []f64{}
	
	// Calculate Volume Force for each bar
	for i := 1; i < data.len; i++ {
		prev_bar := data[i-1]
		current_bar := data[i]
		
		// Calculate typical prices
		prev_typical := (prev_bar.high + prev_bar.low + prev_bar.close) / 3.0
		current_typical := (current_bar.high + current_bar.low + current_bar.close) / 3.0
		
		// Calculate volume trend
		mut volume_trend := 0.0
		if current_typical > prev_typical {
			volume_trend = current_bar.volume
		} else if current_typical < prev_typical {
			volume_trend = -current_bar.volume
		} else {
			volume_trend = 0.0
		}
		
		// Calculate high-low range
		high_low_range := current_bar.high - current_bar.low
		prev_high_low_range := prev_bar.high - prev_bar.low
		
		// Calculate temp
		mut temp := 0.0
		if high_low_range != 0.0 && prev_high_low_range != 0.0 {
			temp = math.abs(2.0 * ((current_bar.high - current_bar.low) / 
					(high_low_range + prev_high_low_range) - 0.5))
		}
		
		// Calculate volume force
		force := volume_trend * temp * 100.0
		volume_force << force
	}

	// Calculate EMAs of volume force
	if volume_force.len < long_period {
		return KlingerOscillatorResult{}
	}

	// Short EMA
	short_ema_config := EMAConfig{period: short_period}
	short_ema := indicators.ema_from_values(volume_force, short_ema_config)
	
	// Long EMA
	long_ema_config := EMAConfig{period: long_period}
	long_ema := indicators.ema_from_values(volume_force, long_ema_config)
	
	if short_ema.len == 0 || long_ema.len == 0 {
		return KlingerOscillatorResult{}
	}

	// Calculate KVO line
	mut kvo_line := []f64{}
	min_len := if short_ema.len < long_ema.len { short_ema.len } else { long_ema.len }
	
	short_start := short_ema.len - min_len
	long_start := long_ema.len - min_len
	
	for i := 0; i < min_len; i++ {
		kvo := short_ema[short_start + i] - long_ema[long_start + i]
		kvo_line << kvo
	}

	// Calculate signal line (EMA of KVO)
	if kvo_line.len < signal_period {
		return KlingerOscillatorResult{
			kvo_line: kvo_line
			signal_line: []f64{}
		}
	}

	signal_config := EMAConfig{period: signal_period}
	signal_line := indicators.ema_from_values(kvo_line, signal_config)

	return KlingerOscillatorResult{
		kvo_line: kvo_line
		signal_line: signal_line
	}
}

// KlingerConfig configuration for Klinger Oscillator
pub struct KlingerConfig {
pub:
	short_period  int // Short EMA period (typically 34)
	long_period   int // Long EMA period (typically 55)
	signal_period int // Signal EMA period (typically 13)
}

// validate validates the KlingerConfig
pub fn (c KlingerConfig) validate() !KlingerConfig {
	if c.short_period <= 0 || c.long_period <= 0 || c.signal_period <= 0 {
		return error('Klinger Oscillator periods must be positive')
	}
	if c.short_period >= c.long_period {
		return error('Klinger Oscillator short period must be less than long period')
	}
	if c.long_period > 1000 || c.signal_period > 1000 {
		return error('Klinger Oscillator periods too large')
	}
	return c
}
