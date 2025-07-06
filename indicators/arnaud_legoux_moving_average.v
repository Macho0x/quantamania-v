module indicators

// arnaud_legoux_moving_average calculates the Arnaud Legoux Moving Average.
// ALMA uses Gaussian distribution weights to reduce noise while maintaining responsiveness.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: ALMAConfig struct with period, sigma, and offset parameters.
//
// Returns:
//   Array of ALMA values.
//   Empty array if insufficient data or invalid parameters.
pub fn arnaud_legoux_moving_average(data []OHLCV, config ALMAConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	sigma := validated_config.sigma
	offset := validated_config.offset
	
	if data.len == 0 || period <= 0 || data.len < period {
		return []f64{}
	}

	// Use close prices for calculation
	mut prices := []f64{}
	for bar in data {
		prices << bar.close
	}

	// Calculate Gaussian weights
	weights := calculate_gaussian_weights(period, sigma, offset)
	
	mut result := []f64{}
	
	for i := period - 1; i < prices.len; i++ {
		mut weighted_sum := 0.0
		mut weight_sum := 0.0
		
		// Apply Gaussian weights to the price window
		for j := 0; j < period; j++ {
			weight := weights[j]
			price := prices[i - j]
			
			weighted_sum += price * weight
			weight_sum += weight
		}
		
		// Calculate ALMA
		if weight_sum > 0.0 {
			result << weighted_sum / weight_sum
		} else {
			result << prices[i]
		}
	}
	
	return result
}

// calculate_gaussian_weights calculates the Gaussian distribution weights for ALMA
fn calculate_gaussian_weights(period int, sigma f64, offset f64) []f64 {
	mut weights := []f64{}
	
	// Calculate the center position based on offset
	center := offset * f64(period - 1)
	
	// Calculate weights using Gaussian distribution
	for i := 0; i < period; i++ {
		// Distance from center
		distance := f64(i) - center
		
		// Gaussian weight calculation
		weight := gaussian_function(distance, sigma)
		weights << weight
	}
	
	return weights
}

// gaussian_function calculates the Gaussian distribution value
fn gaussian_function(x f64, sigma f64) f64 {
	// Gaussian function: exp(-(x^2) / (2 * sigma^2))
	exponent := -(x * x) / (2.0 * sigma * sigma)
	return exp(exponent)
}

// abs calculates the absolute value
fn abs(x f64) f64 {
	return if x >= 0.0 { x } else { -x }
}

// exp calculates the exponential function using Taylor series approximation
fn exp(x f64) f64 {
	if x > 700.0 {
		return 1e300 // Approximate infinity
	}
	if x < -700.0 {
		return 0.0
	}
	
	// Use Taylor series for small values
	if abs(x) < 0.1 {
		return 1.0 + x + (x * x) / 2.0 + (x * x * x) / 6.0
	}
	
	// For larger values, use the fact that e^x = (e^(x/2))^2
	if x > 0 {
		half_exp := exp(x / 2.0)
		return half_exp * half_exp
	} else {
		return 1.0 / exp(-x)
	}
} 