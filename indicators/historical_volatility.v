module indicators

// historical_volatility calculates the Historical Volatility for the given period.
// Historical volatility measures the standard deviation of price returns.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: HistoricalVolatilityConfig struct with period parameter.
//
// Returns:
//   Array of historical volatility values (annualized).
//   Empty array if insufficient data or invalid period.
pub fn historical_volatility(data []OHLCV, config HistoricalVolatilityConfig) []f64 {
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

	// Calculate log returns
	mut log_returns := []f64{}
	for i := 1; i < prices.len; i++ {
		if prices[i-1] > 0.0 {
			log_return := ln(prices[i] / prices[i-1])
			log_returns << log_return
		} else {
			log_returns << 0.0
		}
	}

	mut result := []f64{}
	
	for i := period - 1; i < log_returns.len; i++ {
		// Calculate mean of log returns for the period
		mut sum := 0.0
		for j := 0; j < period; j++ {
			sum += log_returns[i - j]
		}
		mean := sum / f64(period)
		
		// Calculate variance of log returns
		mut variance := 0.0
		for j := 0; j < period; j++ {
			diff := log_returns[i - j] - mean
			variance += diff * diff
		}
		variance /= f64(period - 1) // Use n-1 for sample variance
		
		// Calculate standard deviation and annualize
		// Assuming daily data, multiply by sqrt(252) for annualization
		std_dev := sqrt(variance)
		annualized_volatility := std_dev * sqrt(252.0)
		
		result << annualized_volatility
	}
	
	return result
} 