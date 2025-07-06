module indicators

// volume_rate_of_change calculates the Volume Rate of Change for the given period.
// Volume ROC measures the momentum of volume changes.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: VolumeROCConfig struct with period parameter.
//
// Returns:
//   Array of Volume ROC values (as percentages).
//   Empty array if insufficient data or invalid period.
pub fn volume_rate_of_change(data []OHLCV, config VolumeROCConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len == 0 || period <= 0 || data.len < period {
		return []f64{}
	}

	// Extract volume data
	mut volumes := []f64{}
	for bar in data {
		volumes << bar.volume
	}

	mut result := []f64{}
	
	for i := period; i < volumes.len; i++ {
		current_volume := volumes[i]
		previous_volume := volumes[i - period]
		
		// Calculate Volume ROC: ((Current Volume - Volume n periods ago) / Volume n periods ago) * 100
		volume_roc := if previous_volume > 0.0 { 
			((current_volume - previous_volume) / previous_volume) * 100.0 
		} else { 
			0.0 
		}
		
		result << volume_roc
	}
	
	return result
} 