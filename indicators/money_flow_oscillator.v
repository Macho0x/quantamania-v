module indicators

// money_flow_oscillator calculates the Money Flow Oscillator.
// The Money Flow Oscillator measures buying and selling pressure
// by analyzing price and volume relationships.
//
// Parameters:
//   data: Array of OHLCV price data.
//   config: MoneyFlowOscillatorConfig struct with period parameter.
//
// Returns:
//   Array of Money Flow Oscillator values.
//   Empty array if insufficient data or invalid parameters.
pub fn money_flow_oscillator(data []OHLCV, config MoneyFlowOscillatorConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len < period {
		return []f64{}
	}

	mut oscillator_values := []f64{}

	for i := period - 1; i < data.len; i++ {
		mut positive_money_flow := 0.0
		mut negative_money_flow := 0.0
		
		// Calculate money flow for each bar in the period
		for j := i - (period - 1); j <= i; j++ {
			typical_price := (data[j].high + data[j].low + data[j].close) / 3.0
			raw_money_flow := typical_price * data[j].volume
			
			// Determine if it's positive or negative money flow
			if j > 0 {
				prev_typical_price := (data[j-1].high + data[j-1].low + data[j-1].close) / 3.0
				
				if typical_price > prev_typical_price {
					positive_money_flow += raw_money_flow
				} else if typical_price < prev_typical_price {
					negative_money_flow += raw_money_flow
				} else {
					// Equal typical prices - split the flow
					positive_money_flow += raw_money_flow * 0.5
					negative_money_flow += raw_money_flow * 0.5
				}
			} else {
				// First bar - treat as positive
				positive_money_flow += raw_money_flow
			}
		}
		
		// Calculate money ratio and oscillator
		mut oscillator := 0.0
		if negative_money_flow > 0.0 {
			money_ratio := positive_money_flow / negative_money_flow
			oscillator = 100.0 - (100.0 / (1.0 + money_ratio))
		} else if positive_money_flow > 0.0 {
			oscillator = 100.0
		} else {
			oscillator = 50.0
		}
		
		oscillator_values << oscillator
	}

	return oscillator_values
}

// MoneyFlowOscillatorConfig configuration for Money Flow Oscillator
pub struct MoneyFlowOscillatorConfig {
pub:
	period int // Period for calculation (typically 14)
}

// validate validates the MoneyFlowOscillatorConfig
pub fn (c MoneyFlowOscillatorConfig) validate() !MoneyFlowOscillatorConfig {
	if c.period <= 0 {
		return error('Money Flow Oscillator period must be positive')
	}
	if c.period < 2 {
		return error('Money Flow Oscillator period must be at least 2')
	}
	if c.period > 1000 {
		return error('Money Flow Oscillator period too large')
	}
	return c
}