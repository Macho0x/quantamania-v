module indicators

// GatorResult contains the Gator Oscillator components
pub struct GatorResult {
pub:
	upper_jaw []f64 // Upper jaw (teeth - lips)
	lower_jaw []f64 // Lower jaw (jaw - teeth)
}

// gator_oscillator calculates the Gator Oscillator based on Alligator components.
// Gator Oscillator measures the relationship between Alligator's jaw, teeth, and lips.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: GatorConfig struct with jaw_period, teeth_period, and lips_period parameters.
//
// Returns:
//   GatorResult with upper and lower jaw arrays.
//   Empty arrays if insufficient data or invalid parameters.
pub fn gator_oscillator(data []OHLCV, config GatorConfig) GatorResult {
	validated_config := config.validate() or { return GatorResult{} }
	jaw_period := validated_config.jaw_period
	teeth_period := validated_config.teeth_period
	lips_period := validated_config.lips_period
	
	if data.len == 0 || data.len < jaw_period {
		return GatorResult{}
	}

	// Calculate Alligator components using median prices
	mut median_prices := []f64{}
	for bar in data {
		median_prices << bar.median_price()
	}
	
	// Create OHLCV data from median prices
	median_data := create_ohlcv_from_prices(median_prices)
	
	// Calculate Alligator lines
	jaw := ema(median_data, EMAConfig{period: jaw_period})
	teeth := ema(median_data, EMAConfig{period: teeth_period})
	lips := ema(median_data, EMAConfig{period: lips_period})
	
	mut upper_jaw := []f64{}
	mut lower_jaw := []f64{}
	
	// Calculate Gator components
	for i := 0; i < jaw.len && i < teeth.len && i < lips.len; i++ {
		// Upper jaw: abs(teeth - lips)
		upper := if teeth[i] > lips[i] { teeth[i] - lips[i] } else { lips[i] - teeth[i] }
		upper_jaw << upper
		
		// Lower jaw: -abs(jaw - teeth)
		lower := if jaw[i] > teeth[i] { -(jaw[i] - teeth[i]) } else { -(teeth[i] - jaw[i]) }
		lower_jaw << lower
	}
	
	return GatorResult{
		upper_jaw: upper_jaw
		lower_jaw: lower_jaw
	}
}

 