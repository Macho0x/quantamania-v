module indicators

// rsi calculates the Relative Strength Index for the given period.
// Uses the close price from OHLCV data.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: RSIConfig struct with period parameter.
//
// Returns:
//   Array of RSI values.
//   Empty array if insufficient data or invalid period.
pub fn rsi(data []OHLCV, config RSIConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return []f64{}
	}

	mut result := []f64{}
	mut gains := []f64{}
	mut losses := []f64{}

	// Calculate initial gains and losses
	for i := 1; i < data.len; i++ {
		change := data[i].close - data[i-1].close
		if change > 0 {
			gains << change
			losses << 0.0
		} else {
			gains << 0.0
			losses << -change
		}
	}

	// Calculate initial average gain and loss
	mut avg_gain := 0.0
	mut avg_loss := 0.0
	for i := 0; i < period; i++ {
		avg_gain += gains[i]
		avg_loss += losses[i]
	}
	avg_gain /= f64(period)
	avg_loss /= f64(period)

	// Calculate initial RS and RSI
	mut rs := if avg_loss == 0.0 { 100.0 } else { avg_gain / avg_loss }
	result << 100.0 - (100.0 / (1.0 + rs))

	// Calculate subsequent RSI values using Wilder's smoothing method
	for i := period; i < gains.len; i++ {
		avg_gain = (avg_gain * f64(period - 1) + gains[i]) / f64(period)
		avg_loss = (avg_loss * f64(period - 1) + losses[i]) / f64(period)

		rs = if avg_loss == 0.0 { 100.0 } else { avg_gain / avg_loss }
		result << 100.0 - (100.0 / (1.0 + rs))
	}

	return result
}
