module indicators

// FibonacciResult contains the Fibonacci retracement levels
pub struct FibonacciResult {
pub:
	level_0_0   []f64 // 0.0% level (swing high)
	level_0_236 []f64 // 23.6% retracement
	level_0_382 []f64 // 38.2% retracement
	level_0_500 []f64 // 50.0% retracement
	level_0_618 []f64 // 61.8% retracement
	level_0_786 []f64 // 78.6% retracement
	level_1_0   []f64 // 100.0% level (swing low)
}

// fibonacci_retracements calculates the Fibonacci retracement levels.
// Fibonacci retracements are based on the swing high and low points.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: FibonacciConfig struct with lookback_period parameter.
//
// Returns:
//   FibonacciResult with Fibonacci retracement level arrays.
//   Empty arrays if insufficient data or invalid period.
pub fn fibonacci_retracements(data []OHLCV, config FibonacciConfig) FibonacciResult {
	validated_config := config.validate() or { return FibonacciResult{} }
	lookback_period := validated_config.lookback_period
	
	if data.len == 0 || data.len < lookback_period {
		return FibonacciResult{}
	}

	mut level_0_0 := []f64{}
	mut level_0_236 := []f64{}
	mut level_0_382 := []f64{}
	mut level_0_500 := []f64{}
	mut level_0_618 := []f64{}
	mut level_0_786 := []f64{}
	mut level_1_0 := []f64{}
	
	// Calculate Fibonacci levels for each bar
	for i := lookback_period - 1; i < data.len; i++ {
		// Find swing high and low in the lookback period
		mut swing_high := data[i].high
		mut swing_low := data[i].low
		
		for j := 0; j < lookback_period; j++ {
			bar := data[i - j]
			if bar.high > swing_high {
				swing_high = bar.high
			}
			if bar.low < swing_low {
				swing_low = bar.low
			}
		}
		
		// Calculate price range
		price_range := swing_high - swing_low
		
		// Calculate Fibonacci levels
		level_0_0 << swing_high
		level_0_236 << swing_high - (price_range * 0.236)
		level_0_382 << swing_high - (price_range * 0.382)
		level_0_500 << swing_high - (price_range * 0.500)
		level_0_618 << swing_high - (price_range * 0.618)
		level_0_786 << swing_high - (price_range * 0.786)
		level_1_0 << swing_low
	}
	
	return FibonacciResult{
		level_0_0: level_0_0
		level_0_236: level_0_236
		level_0_382: level_0_382
		level_0_500: level_0_500
		level_0_618: level_0_618
		level_0_786: level_0_786
		level_1_0: level_1_0
	}
} 