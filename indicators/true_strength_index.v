module indicators

// true_strength_index calculates the True Strength Index (TSI).
// TSI is a momentum oscillator that smooths price changes
// to reduce noise and identify trend strength.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: TSIConfig struct with long_period and short_period parameters.
//
// Returns:
//   Array of TSI values ranging from -100 to +100.
//   Empty array if insufficient data or invalid parameters.
pub fn true_strength_index(data []OHLCV, config TSIConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	long_period := validated_config.long_period
	short_period := validated_config.short_period
	
	min_required := long_period + short_period
	if data.len < min_required {
		return []f64{}
	}

	// Calculate price changes
	mut price_changes := []f64{}
	for i := 1; i < data.len; i++ {
		change := data[i].close - data[i-1].close
		price_changes << change
	}

	// Calculate absolute price changes
	mut abs_changes := []f64{}
	for change in price_changes {
		abs_changes << if change < 0 { -change } else { change }
	}

	// First smoothing (EMA of price changes)
	ema_config1 := EMAConfig{period: long_period}
	smoothed_changes := indicators.ema_from_values(price_changes, ema_config1)
	smoothed_abs_changes := indicators.ema_from_values(abs_changes, ema_config1)

	if smoothed_changes.len == 0 || smoothed_abs_changes.len == 0 {
		return []f64{}
	}

	// Second smoothing (EMA of smoothed changes)
	ema_config2 := EMAConfig{period: short_period}
	double_smoothed_changes := indicators.ema_from_values(smoothed_changes, ema_config2)
	double_smoothed_abs_changes := indicators.ema_from_values(smoothed_abs_changes, ema_config2)

	if double_smoothed_changes.len == 0 || double_smoothed_abs_changes.len == 0 {
		return []f64{}
	}

	// Calculate TSI values
	mut tsi_values := []f64{}
	min_len := if double_smoothed_changes.len < double_smoothed_abs_changes.len {
		double_smoothed_changes.len
	} else {
		double_smoothed_abs_changes.len
	}

	for i := 0; i < min_len; i++ {
		if double_smoothed_abs_changes[i] != 0.0 {
			tsi := 100.0 * (double_smoothed_changes[i] / double_smoothed_abs_changes[i])
			tsi_values << tsi
		} else {
			tsi_values << 0.0
		}
	}

	return tsi_values
}

// TSIConfig configuration for True Strength Index
pub struct TSIConfig {
pub:
	long_period  int // Long EMA period (typically 25)
	short_period int // Short EMA period (typically 13)
}

// validate validates the TSIConfig
pub fn (c TSIConfig) validate() !TSIConfig {
    if c.long_period <= 0 || c.short_period <= 0 {
        return error('TSI periods must be positive')
    }
    if c.long_period > 1000 || c.short_period > 1000 {
        return error('TSI periods too large')
    }
    if c.short_period >= c.long_period {
        return error('TSI short period must be less than long period')
    }
    return c
}
