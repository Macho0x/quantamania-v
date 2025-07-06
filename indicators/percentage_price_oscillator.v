module indicators

// PPOResult contains the PPO line and signal line values
pub struct PPOResult {
pub:
	ppo_line    []f64 // Percentage Price Oscillator line
	signal_line []f64 // Signal line (EMA of PPO)
	histogram   []f64 // Histogram (PPO - Signal)
}

// percentage_price_oscillator calculates the Percentage Price Oscillator.
// PPO measures the percentage difference between two EMAs.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: PPOConfig struct with fast_period, slow_period, and signal_period parameters.
//
// Returns:
//   PPOResult with PPO line, signal line, and histogram arrays.
//   Empty arrays if insufficient data or invalid parameters.
pub fn percentage_price_oscillator(data []OHLCV, config PPOConfig) PPOResult {
	validated_config := config.validate() or { return PPOResult{} }
	fast_period := validated_config.fast_period
	slow_period := validated_config.slow_period
	signal_period := validated_config.signal_period
	
	if data.len == 0 || data.len < slow_period {
		return PPOResult{}
	}

	// Calculate fast and slow EMAs
	fast_ema := ema(data, EMAConfig{period: fast_period})
	slow_ema := ema(data, EMAConfig{period: slow_period})
	
	mut ppo_line := []f64{}
	
	// Calculate PPO line: ((Fast EMA - Slow EMA) / Slow EMA) * 100
	for i := 0; i < fast_ema.len && i < slow_ema.len; i++ {
		ppo_value := if slow_ema[i] != 0.0 { 
			((fast_ema[i] - slow_ema[i]) / slow_ema[i]) * 100.0 
		} else { 
			0.0 
		}
		ppo_line << ppo_value
	}
	
	// Calculate signal line (EMA of PPO line)
	ppo_data := create_ohlcv_from_prices(ppo_line)
	signal_line := ema(ppo_data, EMAConfig{period: signal_period})
	
	// Calculate histogram
	mut histogram := []f64{}
	for i := 0; i < ppo_line.len && i < signal_line.len; i++ {
		histogram << ppo_line[i] - signal_line[i]
	}
	
	return PPOResult{
		ppo_line: ppo_line
		signal_line: signal_line
		histogram: histogram
	}
}

 