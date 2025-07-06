module indicators

// double_exponential_moving_average calculates the Double Exponential Moving Average for the given period.
// DEMA reduces lag by applying EMA twice and subtracting the lag.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: DEMAConfig struct with period parameter.
//
// Returns:
//   Array of DEMA values.
//   Empty array if insufficient data or invalid period.
pub fn double_exponential_moving_average(data []OHLCV, config DEMAConfig) []f64 {
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

	// Calculate first EMA
	ema1 := ema(data, EMAConfig{period: period})
	
	// Calculate EMA of EMA1
	ema1_data := create_ohlcv_from_prices(ema1)
	ema2 := ema(ema1_data, EMAConfig{period: period})
	
	// Calculate DEMA: 2 * EMA1 - EMA2
	mut result := []f64{}
	for i := 0; i < ema1.len && i < ema2.len; i++ {
		result << 2.0 * ema1[i] - ema2[i]
	}
	
	return result
}

// create_ohlcv_from_prices creates OHLCV data from price array for EMA calculation
fn create_ohlcv_from_prices(prices []f64) []OHLCV {
	mut result := []OHLCV{}
	for price in prices {
		result << OHLCV{
			open: price
			high: price
			low: price
			close: price
			volume: 1.0
		}
	}
	return result
} 