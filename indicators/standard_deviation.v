module indicators

// standard_deviation calculates the Standard Deviation for the given period.
// Standard deviation measures the dispersion of price data around the mean.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: StdDevConfig struct with period parameter.
//
// Returns:
//   Array of standard deviation values.
//   Empty array if insufficient data or invalid period.
pub fn standard_deviation(data []OHLCV, config StdDevConfig) []f64 {
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
	
	for i := period - 1; i < prices.len; i++ {
		// Calculate mean for the period
		mut sum := 0.0
		for j := 0; j < period; j++ {
			sum += prices[i - j]
		}
		mean := sum / f64(period)
		
		// Calculate variance
		mut variance := 0.0
		for j := 0; j < period; j++ {
			diff := prices[i - j] - mean
			variance += diff * diff
		}
		variance /= f64(period)
		
		// Calculate standard deviation
		std_dev := sqrt(variance)
		result << std_dev
	}
	
	return result
} 