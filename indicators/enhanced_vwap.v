module indicators

// EnhancedVWAPResult contains the enhanced VWAP components
pub struct EnhancedVWAPResult {
pub:
	vwap        []f64 // Volume Weighted Average Price
	upper_band  []f64 // Upper VWAP band
	lower_band  []f64 // Lower VWAP band
	deviation   []f64 // Price deviation from VWAP
}

// enhanced_vwap calculates the Enhanced Volume Weighted Average Price with bands.
// Enhanced VWAP includes standard deviation bands and price deviation analysis.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: EnhancedVWAPConfig struct with period parameter.
//
// Returns:
//   EnhancedVWAPResult with VWAP, bands, and deviation arrays.
//   Empty arrays if insufficient data or invalid period.
pub fn enhanced_vwap(data []OHLCV, config EnhancedVWAPConfig) EnhancedVWAPResult {
	validated_config := config.validate() or { return EnhancedVWAPResult{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return EnhancedVWAPResult{}
	}

	mut vwap_values := []f64{}
	mut upper_bands := []f64{}
	mut lower_bands := []f64{}
	mut deviations := []f64{}
	
	// Calculate VWAP and bands for each period
	for i := period - 1; i < data.len; i++ {
		mut cumulative_pv := 0.0
		mut cumulative_volume := 0.0
		mut price_volume_products := []f64{}
		mut volumes := []f64{}
		
		// Calculate cumulative price * volume for the period
		for j := 0; j < period; j++ {
			bar := data[i - j]
			typical_price := bar.typical_price()
			pv := typical_price * bar.volume
			
			cumulative_pv += pv
			cumulative_volume += bar.volume
			price_volume_products << pv
			volumes << bar.volume
		}
		
		// Calculate VWAP
		vwap_value := if cumulative_volume > 0.0 { 
			cumulative_pv / cumulative_volume 
		} else { 
			data[i].typical_price() 
		}
		vwap_values << vwap_value
		
		// Calculate standard deviation for bands
		mut variance := 0.0
		for j := 0; j < period; j++ {
			bar := data[i - j]
			typical_price := bar.typical_price()
			diff := typical_price - vwap_value
			variance += diff * diff
		}
		variance /= f64(period)
		std_dev := sqrt(variance)
		
		// Calculate bands (2 standard deviations)
		upper_band := vwap_value + (2.0 * std_dev)
		lower_band := vwap_value - (2.0 * std_dev)
		
		upper_bands << upper_band
		lower_bands << lower_band
		
		// Calculate price deviation from VWAP
		current_price := data[i].close
		deviation := if vwap_value > 0.0 { 
			((current_price - vwap_value) / vwap_value) * 100.0 
		} else { 
			0.0 
		}
		deviations << deviation
	}
	
	return EnhancedVWAPResult{
		vwap: vwap_values
		upper_band: upper_bands
		lower_band: lower_bands
		deviation: deviations
	}
} 