module indicators

// detrended_price_oscillator calculates the Detrended Price Oscillator for the given period.
// DPO removes the trend from price data to identify cycles and overbought/oversold conditions.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: DPOConfig struct with period parameter.
//
// Returns:
//   Array of DPO values.
//   Empty array if insufficient data or invalid period.
pub fn detrended_price_oscillator(data []OHLCV, config DPOConfig) []f64 {
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

	// Calculate SMA for the period
	sma_values := sma(data, SMAConfig{period: period})
	
	mut result := []f64{}
	
	// Calculate DPO: Price - SMA shifted back by (period/2 + 1)
	shift := period / 2 + 1
	
	for i := 0; i < prices.len && i < sma_values.len + shift; i++ {
		if i >= shift && i - shift < sma_values.len {
			// DPO = Current Price - SMA shifted back
			dpo_value := prices[i] - sma_values[i - shift]
			result << dpo_value
		}
	}
	
	return result
} 