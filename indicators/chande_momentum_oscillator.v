module indicators

// chande_momentum_oscillator calculates the Chande Momentum Oscillator for the given period.
// CMO is similar to RSI but uses a different calculation method.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: CMOConfig struct with period parameter.
//
// Returns:
//   Array of CMO values (ranging from -100 to +100).
//   Empty array if insufficient data or invalid period.
pub fn chande_momentum_oscillator(data []OHLCV, config CMOConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return []f64{}
	}

	// Use close prices for calculation
	mut prices := []f64{}
	for bar in data {
		prices << bar.close
	}

	mut result := []f64{}
	mut gains := []f64{}
	mut losses := []f64{}

	// Calculate gains and losses
	for i := 1; i < prices.len; i++ {
		change := prices[i] - prices[i-1]
		if change > 0 {
			gains << change
			losses << 0.0
		} else {
			gains << 0.0
			losses << -change
		}
	}

	// Calculate initial sum of gains and losses
	mut sum_gains := 0.0
	mut sum_losses := 0.0
	for i := 0; i < period; i++ {
		sum_gains += gains[i]
		sum_losses += losses[i]
	}

	// Calculate initial CMO
	cmo_value := if sum_gains + sum_losses > 0.0 { 
		((sum_gains - sum_losses) / (sum_gains + sum_losses)) * 100.0 
	} else { 
		0.0 
	}
	result << cmo_value

	// Calculate subsequent CMO values using Wilder's smoothing
	for i := period; i < gains.len; i++ {
		sum_gains = (sum_gains * f64(period - 1) + gains[i]) / f64(period)
		sum_losses = (sum_losses * f64(period - 1) + losses[i]) / f64(period)

		next_cmo_value := if sum_gains + sum_losses > 0.0 { 
			((sum_gains - sum_losses) / (sum_gains + sum_losses)) * 100.0 
		} else { 
			0.0 
		}
		result << next_cmo_value
	}

	return result
} 