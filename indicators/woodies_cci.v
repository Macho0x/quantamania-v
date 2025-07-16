module indicators

// woodies_cci calculates Woodies CCI (Commodity Channel Index).
// Woodies CCI is a variation of the standard CCI that uses
// a different calculation method and includes a Trend Line Break (TLB) component.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: WoodiesCCIConfig struct with cci_period and tlb_period parameters.
//
// Returns:
//   cci_line: Array of Woodies CCI values
//   tlb_line: Array of Trend Line Break (TLB) values
//   Both arrays empty if insufficient data or invalid parameters.
pub fn woodies_cci(data []OHLCV, config WoodiesCCIConfig) ([]f64, []f64) {
	validated_config := config.validate() or { return []f64{}, []f64{} }
	cci_period := validated_config.cci_period
	tlb_period := validated_config.tlb_period
	
	if data.len < cci_period {
		return []f64{}, []f64{}
	}

	mut cci_values := []f64{}
	mut tlb_values := []f64{}

	// Calculate CCI values
	for i := cci_period - 1; i < data.len; i++ {
		// Calculate typical prices for the period
		mut typical_prices := []f64{}
		for j := i - (cci_period - 1); j <= i; j++ {
			typical_price := (data[j].high + data[j].low + data[j].close) / 3.0
			typical_prices << typical_price
		}
		
		// Calculate simple moving average of typical prices
		mut sum := 0.0
		for price in typical_prices {
			sum += price
		}
		sma := sum / f64(cci_period)
		
		// Calculate mean deviation
		mut mean_dev := 0.0
		for price in typical_prices {
			mean_dev += if price - sma > 0.0 { price - sma } else { sma - price }
		}
		mean_dev /= f64(cci_period)
		
		// Calculate current typical price
		current_typical := (data[i].high + data[i].low + data[i].close) / 3.0
		
		// Calculate Woodies CCI
		mut cci := 0.0
		if mean_dev > 0.0 {
			cci = (current_typical - sma) / (0.015 * mean_dev)
		} else {
			cci = 0.0
		}
		
		cci_values << cci
	}

	// Calculate TLB (Trend Line Break) - simple moving average of CCI
	if cci_values.len >= tlb_period {
		for i := tlb_period - 1; i < cci_values.len; i++ {
			mut tlb_sum := 0.0
			for j := i - (tlb_period - 1); j <= i; j++ {
				tlb_sum += cci_values[j]
			}
			tlb_values << tlb_sum / f64(tlb_period)
		}
		
		// Pad beginning with zeros to match lengths
		for tlb_values.len < cci_values.len {
			tlb_values.insert(0, 0.0)
		}
	} else {
		// Not enough data for TLB, return zeros
		for _ in 0 .. cci_values.len {
			tlb_values << 0.0
		}
	}

	return cci_values, tlb_values
}

// WoodiesCCIConfig configuration for Woodies CCI
pub struct WoodiesCCIConfig {
pub:
	cci_period int // Period for CCI calculation (typically 14)
	tlb_period int // Period for Trend Line Break calculation (typically 6)
}

// validate validates the WoodiesCCIConfig
pub fn (c WoodiesCCIConfig) validate() !WoodiesCCIConfig {
	if c.cci_period <= 0 {
		return error('Woodies CCI cci_period must be positive')
	}
	if c.cci_period < 2 {
		return error('Woodies CCI cci_period must be at least 2')
	}
	if c.cci_period > 1000 {
		return error('Woodies CCI cci_period too large')
	}
	if c.tlb_period <= 0 {
		return error('Woodies CCI tlb_period must be positive')
	}
	if c.tlb_period < 2 {
		return error('Woodies CCI tlb_period must be at least 2')
	}
	if c.tlb_period > 1000 {
		return error('Woodies CCI tlb_period too large')
	}
	return c
}