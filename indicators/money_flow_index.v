module indicators

// money_flow_index calculates the Money Flow Index (MFI).
pub fn money_flow_index(data []OHLCV, config MFIConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	period := validated_config.period
	
	if data.len < period + 1 {
		return []f64{}
	}

	mut typical_prices := []f64{}
	for d in data {
		typical_prices << (d.high + d.low + d.close) / 3.0
	}

	mut positive_money_flow := []f64{}
	mut negative_money_flow := []f64{}

	for i := 1; i < typical_prices.len; i++ {
		if typical_prices[i] > typical_prices[i-1] {
			positive_money_flow << typical_prices[i] * data[i].volume
			negative_money_flow << 0.0
		} else if typical_prices[i] < typical_prices[i-1] {
			negative_money_flow << typical_prices[i] * data[i].volume
			positive_money_flow << 0.0
		} else {
			positive_money_flow << 0.0
			negative_money_flow << 0.0
		}
	}

	mut mfi_values := []f64{}
	for i := period -1; i < positive_money_flow.len; i++ {
		mut positive_sum := 0.0
		mut negative_sum := 0.0
		for j := i - (period - 1); j <=i; j++ {
			positive_sum += positive_money_flow[j]
			negative_sum += negative_money_flow[j]
		}

		money_ratio := if negative_sum == 0.0 { 100.0 } else { positive_sum / negative_sum }
		mfi := 100.0 - (100.0 / (1.0 + money_ratio))
		mfi_values << mfi
	}

	return mfi_values
}
