module indicators

// vortex_indicator calculates the Vortex Indicator (+VI and -VI).
pub fn vortex_indicator(data []OHLCV, config VortexConfig) ([]f64, []f64) {
	validated_config := config.validate() or { return []f64{}, []f64{} }
	period := validated_config.period
	
    if data.len < period + 1 {
        return []f64{}, []f64{}
    }

    mut plus_vm := []f64{}
    mut minus_vm := []f64{}
    mut tr := []f64{}

    for i := 1; i < data.len; i++ {
        plus_vm << if data[i].high - data[i-1].low > 0 { data[i].high - data[i-1].low } else { data[i-1].low - data[i].high }
        minus_vm << if data[i].low - data[i-1].high > 0 { data[i].low - data[i-1].high } else { data[i-1].high - data[i].low }

        tr1 := data[i].high - data[i].low
        tr2 := if data[i].high - data[i-1].close > 0 { data[i].high - data[i-1].close } else { data[i-1].close - data[i].high }
        tr3 := if data[i].low - data[i-1].close > 0 { data[i].low - data[i-1].close } else { data[i-1].close - data[i].low }
        max_tr := if tr1 > tr2 { tr1 } else { tr2 }
        tr << if max_tr > tr3 { max_tr } else { tr3 }
    }

    mut plus_vi_values := []f64{}
    mut minus_vi_values := []f64{}

    for i := period - 1; i < plus_vm.len; i++ {
        mut plus_vm_sum := 0.0
        mut minus_vm_sum := 0.0
        mut tr_sum := 0.0

        for j := i - (period - 1); j <= i; j++ {
            plus_vm_sum += plus_vm[j]
            minus_vm_sum += minus_vm[j]
            tr_sum += tr[j]
        }

        plus_vi := if tr_sum == 0.0 { 0.0 } else { plus_vm_sum / tr_sum }
        minus_vi := if tr_sum == 0.0 { 0.0 } else { minus_vm_sum / tr_sum }

        plus_vi_values << plus_vi
        minus_vi_values << minus_vi
    }

    return plus_vi_values, minus_vi_values
}
