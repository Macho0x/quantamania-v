module indicators

// FisherResult contains the Fisher Transform and trigger line values
pub struct FisherResult {
pub:
	fisher []f64 // Fisher Transform values
	trigger []f64 // Trigger line (previous Fisher value)
}

// fisher_transform calculates the Fisher Transform for the given period.
// Fisher Transform converts price data to a Gaussian distribution for better signal identification.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: FisherConfig struct with period parameter.
//
// Returns:
//   FisherResult with Fisher Transform and trigger line arrays.
//   Empty arrays if insufficient data or invalid period.
pub fn fisher_transform(data []OHLCV, config FisherConfig) FisherResult {
	validated_config := config.validate() or { return FisherResult{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return FisherResult{}
	}

	// Use close prices for calculation
	mut prices := []f64{}
	for bar in data {
		prices << bar.close
	}

	// Calculate highest high and lowest low for the period
	mut highest_high := []f64{}
	mut lowest_low := []f64{}
	
	for i := period - 1; i < prices.len; i++ {
		mut high := prices[i]
		mut low := prices[i]
		
		for j := 0; j < period; j++ {
			price := prices[i - j]
			if price > high {
				high = price
			}
			if price < low {
				low = price
			}
		}
		
		highest_high << high
		lowest_low << low
	}

	// Calculate value1 (normalized price position)
	mut value1 := []f64{}
	for i := 0; i < highest_high.len; i++ {
		price := prices[i + period - 1]
		high := highest_high[i]
		low := lowest_low[i]
		
		value := if high != low { 
			0.33 * 2.0 * ((price - low) / (high - low) - 0.5) + 0.67 * (if value1.len > 0 { value1[value1.len - 1] } else { 0.0 })
		} else { 
			if value1.len > 0 { value1[value1.len - 1] } else { 0.0 }
		}
		
		// Limit value1 to range [-0.99, 0.99]
		mut limited_value := value
		if limited_value > 0.99 {
			limited_value = 0.99
		} else if limited_value < -0.99 {
			limited_value = -0.99
		}
		
		value1 << limited_value
	}

	// Calculate Fisher Transform
	mut fisher := []f64{}
	for value in value1 {
		// Fisher Transform formula: 0.5 * ln((1 + x) / (1 - x))
		fisher_value := 0.5 * ln((1.0 + value) / (1.0 - value))
		fisher << fisher_value
	}

	// Calculate trigger line (previous Fisher value)
	mut trigger := []f64{}
	for i := 0; i < fisher.len; i++ {
		if i > 0 {
			trigger << fisher[i - 1]
		} else {
			trigger << 0.0
		}
	}

	return FisherResult{
		fisher: fisher
		trigger: trigger
	}
}

// ln calculates the natural logarithm using approximation
fn ln(x f64) f64 {
	if x <= 0.0 {
		return 0.0
	}
	
	// Use the fact that ln(x) = ln(2) * log2(x)
	// For small values, use Taylor series approximation
	if x < 0.1 {
		return x - (x * x) / 2.0 + (x * x * x) / 3.0
	}
	
	// For larger values, use ln(2) = 0.693147
	ln2 := 0.6931471805599453
	return ln2 * log2(x)
}

// log2 calculates the base-2 logarithm
fn log2(x f64) f64 {
	if x <= 0.0 {
		return 0.0
	}
	
	// Use the fact that log2(x) = ln(x) / ln(2)
	// For simplicity, we'll use a basic approximation
	mut result := 0.0
	mut temp := x
	
	// Find the integer part
	for temp >= 2.0 {
		result += 1.0
		temp /= 2.0
	}
	for temp < 1.0 && temp > 0.0 {
		result -= 1.0
		temp *= 2.0
	}
	
	// Add fractional part approximation
	if temp > 1.0 {
		result += (temp - 1.0) / (temp + 1.0) * 2.0
	}
	
	return result
} 