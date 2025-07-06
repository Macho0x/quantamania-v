module indicators

// chaikin_volatility calculates the Chaikin Volatility indicator for the given period.
// Chaikin Volatility measures the volatility based on the high-low range.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: ChaikinVolatilityConfig struct with period parameter.
//
// Returns:
//   Array of Chaikin Volatility values.
//   Empty array if insufficient data or invalid period.
pub fn chaikin_volatility(data []OHLCV, config ChaikinVolatilityConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return []f64{}
	}

	// Calculate high-low ranges
	mut ranges := []f64{}
	for bar in data {
		range_value := bar.high - bar.low
		ranges << range_value
	}

	// Calculate EMA of high-low ranges
	range_data := create_ohlcv_from_prices(ranges)
	ema_ranges := ema(range_data, EMAConfig{period: period})
	
	mut result := []f64{}
	
	// Calculate Chaikin Volatility: (EMA of ranges - EMA of ranges n periods ago) / EMA of ranges n periods ago
	for i := period; i < ema_ranges.len; i++ {
		current_ema := ema_ranges[i]
		previous_ema := ema_ranges[i - period]
		
		chaikin_value := if previous_ema > 0.0 { 
			((current_ema - previous_ema) / previous_ema) * 100.0 
		} else { 
			0.0 
		}
		
		result << chaikin_value
	}
	
	return result
}

 