module indicators

// price_rate_of_change calculates the Price Rate of Change for the given period.
// PROC measures the percentage change in price over a specified period.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: PROCConfig struct with period parameter.
//
// Returns:
//   Array of PROC values (as percentages).
//   Empty array if insufficient data or invalid period.
pub fn price_rate_of_change(data []OHLCV, config PROCConfig) []f64 {
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
		// PROC = ((Current Price - Price n periods ago) / Price n periods ago) * 100
		price_change := prices[i] - prices[i - period]
		proc_value := if prices[i - period] != 0.0 { 
			(price_change / prices[i - period]) * 100.0 
		} else { 
			0.0 
		}
		result << proc_value
	}
	
	return result
} 