module indicators
import math

// choppiness_index calculates the Choppiness Index.
// The Choppiness Index measures whether a market is trending
// or in a sideways/choppy phase.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: ChoppinessConfig struct with period parameter.
//
// Returns:
//   Array of Choppiness Index values (0-100).
//   Lower values indicate trending, higher values indicate choppy.
//   Empty array if insufficient data or invalid parameters.
pub fn choppiness_index(data []OHLCV, config ChoppinessConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len < period {
		return []f64{}
	}

	mut choppiness_values := []f64{}

	for i := period - 1; i < data.len; i++ {
		// Get the period data
		period_data := data[i - (period - 1)..i + 1]
		
		// Find highest high and lowest low in the period
		mut highest_high := period_data[0].high
		mut lowest_low := period_data[0].low
		
		for bar in period_data {
			if bar.high > highest_high {
				highest_high = bar.high
			}
			if bar.low < lowest_low {
				lowest_low = bar.low
			}
		}
		
		// Calculate ATR for the period
		mut atr_sum := 0.0
		for j := 1; j < period_data.len; j++ {
			prev_close := period_data[j-1].close
			high := period_data[j].high
			low := period_data[j].low
			
			tr1 := high - low
			tr2 := if high - prev_close > 0 { high - prev_close } else { prev_close - high }
			tr3 := if low - prev_close > 0 { low - prev_close } else { prev_close - low }
			
			mut max_tr := tr1
			if tr2 > max_tr {
				max_tr = tr2
			}
			if tr3 > max_tr {
				max_tr = tr3
			}
			
			atr_sum += max_tr
		}
		
		atr := atr_sum / f64(period - 1)
		
		// Calculate Choppiness Index
		total_range := highest_high - lowest_low
		if total_range > 0.0 && atr > 0.0 {
			// Sum of ATR values
			sum_atr := atr * f64(period - 1)
			
			// Choppiness Index formula
			log_ratio := log10(sum_atr / total_range)
			log_period := log10(f64(period))
			
			mut choppiness := 100.0 * log_ratio / log_period
			
			// Ensure values are within 0-100 range
			if choppiness < 0.0 {
				choppiness = 0.0
			} else if choppiness > 100.0 {
				choppiness = 100.0
			}
			
			choppiness_values << choppiness
		} else {
			choppiness_values << 0.0
		}
	}

	return choppiness_values
}

// ChoppinessConfig configuration for Choppiness Index
pub struct ChoppinessConfig {
pub:
	period int // Period for calculation (typically 14)
}

// validate validates the ChoppinessConfig
pub fn (c ChoppinessConfig) validate() !ChoppinessConfig {
	if c.period <= 0 {
		return error('Choppiness Index period must be positive')
	}
	if c.period < 5 {
		return error('Choppiness Index period must be at least 5')
	}
	if c.period > 1000 {
		return error('Choppiness Index period too large')
	}
	return c
}

// log10 calculates base-10 logarithm
fn log10(x f64) f64 {
	if x <= 0.0 {
		return 0.0
	}
	return log_natural(x) / log_natural(10.0)
}

// log_natural calculates natural logarithm using Taylor series approximation
fn log_natural(x f64) f64 {
	if x <= 0.0 {
		return 0.0
	}
	
	// Use simple approximation for natural log
	mut result := 0.0
	mut term := (x - 1.0) / (x + 1.0)
	mut term_sq := term * term
	mut current_term := term
	
	for i := 1; i <= 100; i += 2 {
		result += current_term / f64(i)
		current_term *= term_sq
		if math.abs(current_term) < 1e-15 {
			break
		}
	}
	
	return 2.0 * result
}