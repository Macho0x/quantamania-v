module indicators

// chaikin_money_flow calculates the CMF.
pub fn chaikin_money_flow(data []OHLCV, config CMFConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len < period {
		return []f64{}
	}

	mut money_flow_volumes := []f64{}
	mut volumes := []f64{}

	for d in data {
		high, low, close, volume := d.high, d.low, d.close, d.volume
		
		// Calculate Money Flow Multiplier
		multiplier := if high == low { 0.0 } else { ((close - low) - (high - close)) / (high - low) }
		
		// Calculate Money Flow Volume
		money_flow_volume := multiplier * volume
		
		money_flow_volumes << money_flow_volume
		volumes << volume
	}

	mut cmf_values := []f64{}
	for i := period - 1; i < data.len; i++ {
		mut mfv_sum := 0.0
		mut vol_sum := 0.0
		for j := i - (period - 1); j <= i; j++ {
			mfv_sum += money_flow_volumes[j]
			vol_sum += volumes[j]
		}
		
		cmf := if vol_sum == 0.0 { 0.0 } else { mfv_sum / vol_sum }
		cmf_values << cmf
	}

	return cmf_values
}

