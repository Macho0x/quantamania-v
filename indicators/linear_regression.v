module indicators

// LinearRegressionResult contains the linear regression line and slope values
pub struct LinearRegressionResult {
pub:
	line  []f64 // Linear regression line values
	slope []f64 // Slope values (rate of change)
}

// linear_regression calculates the linear regression line and slope for the given period.
// Uses the close price from OHLCV data.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: LinearRegressionConfig struct with period parameter.
//
// Returns:
//   LinearRegressionResult with line and slope arrays.
//   Empty arrays if insufficient data or invalid period.
pub fn linear_regression(data []OHLCV, config LinearRegressionConfig) LinearRegressionResult {
	validated_config := config.validate() or { return LinearRegressionResult{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return LinearRegressionResult{}
	}

	// Use close prices for calculation
	mut prices := []f64{}
	for bar in data {
		prices << bar.close
	}

	mut line := []f64{}
	mut slope := []f64{}
	
	for i := period - 1; i < prices.len; i++ {
		// Get the window of prices for this period
		window := prices[i - period + 1..i + 1].clone()
		
		// Calculate linear regression for this window
		regression := calculate_linear_regression(window)
		
		// The line value is the predicted value for the current position
		line << regression.intercept + regression.slope * f64(period - 1)
		slope << regression.slope
	}
	
	return LinearRegressionResult{
		line: line
		slope: slope
	}
}

// RegressionCoefficients contains the slope and intercept of a linear regression
struct RegressionCoefficients {
	slope     f64
	intercept f64
}

// calculate_linear_regression calculates the linear regression coefficients for a data window
fn calculate_linear_regression(data []f64) RegressionCoefficients {
	n := f64(data.len)
	
	// Calculate sums
	mut sum_x := 0.0
	mut sum_y := 0.0
	mut sum_xy := 0.0
	mut sum_x2 := 0.0
	
	for i := 0; i < data.len; i++ {
		x := f64(i)
		y := data[i]
		
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x2 += x * x
	}
	
	// Calculate slope and intercept using least squares method
	denominator := n * sum_x2 - sum_x * sum_x
	if denominator == 0.0 {
		return RegressionCoefficients{slope: 0.0, intercept: data[0]}
	}
	
	slope := (n * sum_xy - sum_x * sum_y) / denominator
	intercept := (sum_y - slope * sum_x) / n
	
	return RegressionCoefficients{
		slope: slope
		intercept: intercept
	}
} 