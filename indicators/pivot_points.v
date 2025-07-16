module indicators

// PivotPointsResult contains the pivot point levels
pub struct PivotPointsResult {
pub:
	pivot_point []f64 // Pivot Point (PP)
	resistance1 []f64 // First Resistance (R1)
	resistance2 []f64 // Second Resistance (R2)
	resistance3 []f64 // Third Resistance (R3)
	support1    []f64 // First Support (S1)
	support2    []f64 // Second Support (S2)
	support3    []f64 // Third Support (S3)
}

// pivot_points calculates the Pivot Points and support/resistance levels.
// Pivot Points are calculated using the previous day's high, low, and close.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: PivotPointsConfig struct.
//
// Returns:
//   PivotPointsResult with pivot point and support/resistance arrays.
//   Empty arrays if insufficient data.
pub fn pivot_points(data []OHLCV, config PivotPointsConfig) PivotPointsResult {
	_ := config.validate() or { return PivotPointsResult{} }
	
	if data.len == 0 || data.len < 2 {
		return PivotPointsResult{}
	}

	mut pivot_point := []f64{}
	mut resistance1 := []f64{}
	mut resistance2 := []f64{}
	mut resistance3 := []f64{}
	mut support1 := []f64{}
	mut support2 := []f64{}
	mut support3 := []f64{}
	
	// Calculate pivot points for each bar using previous bar's data
	for i := 1; i < data.len; i++ {
		previous := data[i - 1]
		
		// Pivot Point = (High + Low + Close) / 3
		pp := (previous.high + previous.low + previous.close) / 3.0
		pivot_point << pp
		
		// First Resistance = (2 * PP) - Low
		r1 := (2.0 * pp) - previous.low
		resistance1 << r1
		
		// Second Resistance = PP + (High - Low)
		r2 := pp + (previous.high - previous.low)
		resistance2 << r2
		
		// Third Resistance = High + 2 * (PP - Low)
		r3 := previous.high + 2.0 * (pp - previous.low)
		resistance3 << r3
		
		// First Support = (2 * PP) - High
		s1 := (2.0 * pp) - previous.high
		support1 << s1
		
		// Second Support = PP - (High - Low)
		s2 := pp - (previous.high - previous.low)
		support2 << s2
		
		// Third Support = Low - 2 * (High - PP)
		s3 := previous.low - 2.0 * (previous.high - pp)
		support3 << s3
	}
	
	return PivotPointsResult{
		pivot_point: pivot_point
		resistance1: resistance1
		resistance2: resistance2
		resistance3: resistance3
		support1: support1
		support2: support2
		support3: support3
	}
} 