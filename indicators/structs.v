module indicators

// OHLCV represents a data point with Open, High, Low, Close, and Volume values.
// This is the standard data structure used throughout the entire indicators library.
pub struct OHLCV {
pub:
	open   f64
	high   f64
	low    f64
	close  f64
	volume f64
}



// Helper methods for OHLCV

// typical_price calculates the typical price (HLC/3)
// Used by indicators like CCI, Keltner Channels, etc.
pub fn (ohlcv OHLCV) typical_price() f64 {
	return (ohlcv.high + ohlcv.low + ohlcv.close) / 3.0
}

// median_price calculates the median price (HL/2)
// Used by some moving averages and oscillators
pub fn (ohlcv OHLCV) median_price() f64 {
	return (ohlcv.high + ohlcv.low) / 2.0
}

// weighted_close calculates the weighted close price (H+L+2C)/4
// Alternative price calculation method
pub fn (ohlcv OHLCV) weighted_close() f64 {
	return (ohlcv.high + ohlcv.low + 2.0 * ohlcv.close) / 4.0
}

// true_range calculates the true range for this bar given the previous close
// Used by ATR, ADX, and other volatility indicators
pub fn (ohlcv OHLCV) true_range(prev_close f64) f64 {
	tr1 := ohlcv.high - ohlcv.low
	tr2 := if ohlcv.high - prev_close > 0 { ohlcv.high - prev_close } else { prev_close - ohlcv.high }
	tr3 := if ohlcv.low - prev_close > 0 { ohlcv.low - prev_close } else { prev_close - ohlcv.low }
	max_tr := if tr1 > tr2 { tr1 } else { tr2 }
	return if max_tr > tr3 { max_tr } else { tr3 }
}

// price_change calculates the price change from previous close
// Used by momentum indicators
pub fn (ohlcv OHLCV) price_change(prev_close f64) f64 {
	return ohlcv.close - prev_close
}

// body_size calculates the size of the candlestick body
// Used for candlestick pattern analysis
pub fn (ohlcv OHLCV) body_size() f64 {
	return if ohlcv.close > ohlcv.open { ohlcv.close - ohlcv.open } else { ohlcv.open - ohlcv.close }
}

// is_bullish returns true if the bar closed higher than it opened
pub fn (ohlcv OHLCV) is_bullish() bool {
	return ohlcv.close > ohlcv.open
}

// is_bearish returns true if the bar closed lower than it opened
pub fn (ohlcv OHLCV) is_bearish() bool {
	return ohlcv.close < ohlcv.open
}

// sqrt calculates the square root using Newton's method
// Used by indicators like Bollinger Bands, standard deviation calculations, etc.
pub fn sqrt(x f64) f64 {
	if x <= 0.0 {
		return 0.0
	}
	mut guess := x / 2.0
	for _ in 0 .. 10 {
		guess = (guess + x / guess) / 2.0
	}
	return guess
}
