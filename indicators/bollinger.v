module indicators

pub fn bollinger_bands(data []OHLCV, config BollingerConfig) ([]f64, []f64, []f64) {
	validated_config := config.validate() or { return []f64{}, []f64{}, []f64{} }
	period := validated_config.period
	num_std_dev := validated_config.num_std_dev
	
	mut close_prices := []f64{}
	for d in data {
		close_prices << d.close
	}
	
	sma_config := SMAConfig{period: period}
	middle_band := sma(data, sma_config)
	standard_deviation := calculate_std_dev(close_prices, period)

	mut upper_band := []f64{}
	mut lower_band := []f64{}

	for i := 0; i < middle_band.len; i++ {
		upper_band << middle_band[i] + (standard_deviation[i] * num_std_dev)
		lower_band << middle_band[i] - (standard_deviation[i] * num_std_dev)
	}

	return upper_band, middle_band, lower_band
}

// calculate_std_dev calculates the standard deviation for a given period
pub fn calculate_std_dev(data []f64, period int) []f64 {
	if data.len < period {
		return []f64{}
	}

	mut std_dev_values := []f64{}
	for i := period - 1; i < data.len; i++ {
		mut sum := 0.0
		for j := i - (period - 1); j <= i; j++ {
			sum += data[j]
		}
		mean := sum / f64(period)
		
		mut variance_sum := 0.0
		for j := i - (period - 1); j <= i; j++ {
			variance_sum += (data[j] - mean) * (data[j] - mean)
		}
		variance := variance_sum / f64(period)
		std_dev := sqrt(variance)
		std_dev_values << std_dev
	}

	return std_dev_values
}


