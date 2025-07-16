module indicators

// momentum calculates the Momentum indicator for the given period.
// Momentum measures the rate of change in price over a specified period.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: MomentumConfig struct with period parameter.
//
// Returns:
//   Array of momentum values.
//   Empty array if insufficient data or invalid period.
pub fn momentum(data []OHLCV, config MomentumConfig) []f64 {
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
	
	for i := period; i < prices.len; i++ {
		// Momentum = Current Price - Price n periods ago
		momentum_value := prices[i] - prices[i - period]
		result << momentum_value
	}
	
	return result
} 