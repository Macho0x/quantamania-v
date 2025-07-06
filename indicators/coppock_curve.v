module indicators

// coppock_curve calculates the Coppock Curve.
pub fn coppock_curve(data []OHLCV, config CoppockConfig) []f64 {
	validated_config := config.validate() or { return []f64{} }
	roc1_period := validated_config.roc1_period
	roc2_period := validated_config.roc2_period
	wma_period := validated_config.wma_period
	
    mut close_prices := []f64{}
	for d in data {
		close_prices << d.close
	}

    if close_prices.len < roc1_period + wma_period || close_prices.len < roc2_period + wma_period {
        return []f64{}
    }

    roc1_config := ROCConfig{period: roc1_period}
    roc2_config := ROCConfig{period: roc2_period}
    
    mut roc1 := rate_of_change(data, roc1_config)
    mut roc2 := rate_of_change(data, roc2_config)

    // Align the ROC series
    if roc1.len > roc2.len {
        roc1 = roc1[roc1.len - roc2.len..].clone()
    } else if roc2.len > roc1.len {
        roc2 = roc2[roc2.len - roc1.len..].clone()
    }

    mut roc_sum := []f64{}
    for i := 0; i < roc1.len; i++ {
        roc_sum << roc1[i] + roc2[i]
    }

    return wma(roc_sum, wma_period)
}

// wma calculates the Weighted Moving Average.
fn wma(data []f64, period int) []f64 {
    if data.len < period {
        return []f64{}
    }

    mut wma_values := []f64{}
    mut weight_sum := 0.0
    for i := 1; i <= period; i++ {
        weight_sum += i
    }

    for i := period - 1; i < data.len; i++ {
        mut weighted_sum := 0.0
        for j := 0; j < period; j++ {
            weighted_sum += data[i - j] * (period - j)
        }
        wma_values << weighted_sum / weight_sum
    }

    return wma_values
}
