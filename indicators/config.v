module indicators

// Base configuration interface
pub interface IndicatorConfig {
	validate() !IndicatorConfig
}

// Simple Moving Average Configuration
pub struct SMAConfig {
pub:
	period int = 20
}

pub fn (c SMAConfig) validate() !SMAConfig {
	if c.period <= 0 {
		return error('SMA period must be greater than 0')
	}
	return c
}

// Exponential Moving Average Configuration
pub struct EMAConfig {
pub:
	period int = 20
}

pub fn (c EMAConfig) validate() !EMAConfig {
	if c.period <= 0 {
		return error('EMA period must be greater than 0')
	}
	return c
}

// Bollinger Bands Configuration
pub struct BollingerConfig {
pub:
	period     int   = 20
	num_std_dev f64 = 2.0
}

pub fn (c BollingerConfig) validate() !BollingerConfig {
	if c.period <= 0 {
		return error('Bollinger period must be greater than 0')
	}
	if c.num_std_dev <= 0 {
		return error('Bollinger standard deviation must be greater than 0')
	}
	return c
}

// Relative Strength Index Configuration
pub struct RSIConfig {
pub:
	period int = 14
}

pub fn (c RSIConfig) validate() !RSIConfig {
	if c.period <= 0 {
		return error('RSI period must be greater than 0')
	}
	return c
}

// Average Directional Index Configuration
pub struct ADXConfig {
pub:
	period int = 14
}

pub fn (c ADXConfig) validate() !ADXConfig {
	if c.period <= 0 {
		return error('ADX period must be greater than 0')
	}
	return c
}

// Moving Average Convergence Divergence Configuration
pub struct MACDConfig {
pub:
	short_period  int = 12
	long_period   int = 26
	signal_period int = 9
}

pub fn (c MACDConfig) validate() !MACDConfig {
	if c.short_period <= 0 {
		return error('MACD short period must be greater than 0')
	}
	if c.long_period <= 0 {
		return error('MACD long period must be greater than 0')
	}
	if c.signal_period <= 0 {
		return error('MACD signal period must be greater than 0')
	}
	if c.short_period >= c.long_period {
		return error('MACD short period must be less than long period')
	}
	return c
}

// Parabolic SAR Configuration
pub struct ParabolicSARConfig {
pub:
	acceleration      f64 = 0.02
	max_acceleration  f64 = 0.2
}

pub fn (c ParabolicSARConfig) validate() !ParabolicSARConfig {
	if c.acceleration <= 0 {
		return error('Parabolic SAR acceleration must be greater than 0')
	}
	if c.max_acceleration <= 0 {
		return error('Parabolic SAR max acceleration must be greater than 0')
	}
	if c.acceleration > c.max_acceleration {
		return error('Parabolic SAR acceleration cannot exceed max acceleration')
	}
	return c
}

// Ichimoku Cloud Configuration
pub struct IchimokuConfig {
pub:
	tenkan_period    int = 9
	kijun_period     int = 26
	senkou_b_period  int = 52
}

pub fn (c IchimokuConfig) validate() !IchimokuConfig {
	if c.tenkan_period <= 0 {
		return error('Ichimoku tenkan period must be greater than 0')
	}
	if c.kijun_period <= 0 {
		return error('Ichimoku kijun period must be greater than 0')
	}
	if c.senkou_b_period <= 0 {
		return error('Ichimoku senkou B period must be greater than 0')
	}
	return c
}

// Stochastic Oscillator Configuration
pub struct StochasticConfig {
pub:
	k_period int = 14
	d_period int = 3
}

pub fn (c StochasticConfig) validate() !StochasticConfig {
	if c.k_period <= 0 {
		return error('Stochastic K period must be greater than 0')
	}
	if c.d_period <= 0 {
		return error('Stochastic D period must be greater than 0')
	}
	return c
}

// Williams %R Configuration
pub struct WilliamsRConfig {
pub:
	period int = 14
}

pub fn (c WilliamsRConfig) validate() !WilliamsRConfig {
	if c.period <= 0 {
		return error('Williams %R period must be greater than 0')
	}
	return c
}

// Commodity Channel Index Configuration
pub struct CCIConfig {
pub:
	period int = 20
}

pub fn (c CCIConfig) validate() !CCIConfig {
	if c.period <= 0 {
		return error('CCI period must be greater than 0')
	}
	return c
}

// Average True Range Configuration
pub struct ATRConfig {
pub:
	period int = 14
}

pub fn (c ATRConfig) validate() !ATRConfig {
	if c.period <= 0 {
		return error('ATR period must be greater than 0')
	}
	return c
}

// Keltner Channels Configuration
pub struct KeltnerConfig {
pub:
	period        int   = 20
	atr_multiplier f64 = 2.0
}

pub fn (c KeltnerConfig) validate() !KeltnerConfig {
	if c.period <= 0 {
		return error('Keltner period must be greater than 0')
	}
	if c.atr_multiplier <= 0 {
		return error('Keltner ATR multiplier must be greater than 0')
	}
	return c
}

// Awesome Oscillator Configuration
pub struct AwesomeOscillatorConfig {
pub:
	short_period int = 5
	long_period  int = 34
}

pub fn (c AwesomeOscillatorConfig) validate() !AwesomeOscillatorConfig {
	if c.short_period <= 0 {
		return error('Awesome Oscillator short period must be greater than 0')
	}
	if c.long_period <= 0 {
		return error('Awesome Oscillator long period must be greater than 0')
	}
	if c.short_period >= c.long_period {
		return error('Awesome Oscillator short period must be less than long period')
	}
	return c
}

// Ultimate Oscillator Configuration
pub struct UltimateOscillatorConfig {
pub:
	period1 int = 7
	period2 int = 14
	period3 int = 28
}

pub fn (c UltimateOscillatorConfig) validate() !UltimateOscillatorConfig {
	if c.period1 <= 0 {
		return error('Ultimate Oscillator period1 must be greater than 0')
	}
	if c.period2 <= 0 {
		return error('Ultimate Oscillator period2 must be greater than 0')
	}
	if c.period3 <= 0 {
		return error('Ultimate Oscillator period3 must be greater than 0')
	}
	return c
}

// TRIX Configuration
pub struct TRIXConfig {
pub:
	period int = 15
}

pub fn (c TRIXConfig) validate() !TRIXConfig {
	if c.period <= 0 {
		return error('TRIX period must be greater than 0')
	}
	return c
}

// Donchian Channels Configuration
pub struct DonchianConfig {
pub:
	period int = 20
}

pub fn (c DonchianConfig) validate() !DonchianConfig {
	if c.period <= 0 {
		return error('Donchian period must be greater than 0')
	}
	return c
}

// Wilder's Smoothing Configuration
pub struct WildersConfig {
pub:
	period int = 14
}

pub fn (c WildersConfig) validate() !WildersConfig {
	if c.period <= 0 {
		return error('Wilder\'s period must be greater than 0')
	}
	return c
}

// Rate of Change Configuration
pub struct ROCConfig {
pub:
	period int = 10
}

pub fn (c ROCConfig) validate() !ROCConfig {
	if c.period <= 0 {
		return error('ROC period must be greater than 0')
	}
	return c
}

// Money Flow Index Configuration
pub struct MFIConfig {
pub:
	period int = 14
}

pub fn (c MFIConfig) validate() !MFIConfig {
	if c.period <= 0 {
		return error('MFI period must be greater than 0')
	}
	return c
}

// Stochastic RSI Configuration
pub struct StochasticRSIConfig {
pub:
	rsi_period int = 14
	k_period   int = 14
	d_period   int = 3
}

pub fn (c StochasticRSIConfig) validate() !StochasticRSIConfig {
	if c.rsi_period <= 0 {
		return error('Stochastic RSI RSI period must be greater than 0')
	}
	if c.k_period <= 0 {
		return error('Stochastic RSI K period must be greater than 0')
	}
	if c.d_period <= 0 {
		return error('Stochastic RSI D period must be greater than 0')
	}
	return c
}

// Know Sure Thing Configuration
pub struct KSTConfig {
pub:
	roc1_period      int = 10
	roc2_period      int = 15
	roc3_period      int = 20
	roc4_period      int = 30
	sma1_period      int = 10
	sma2_period      int = 10
	sma3_period      int = 10
	sma4_period      int = 15
	signal_period    int = 9
}

pub fn (c KSTConfig) validate() !KSTConfig {
	if c.roc1_period <= 0 {
		return error('KST ROC1 period must be greater than 0')
	}
	if c.roc2_period <= 0 {
		return error('KST ROC2 period must be greater than 0')
	}
	if c.roc3_period <= 0 {
		return error('KST ROC3 period must be greater than 0')
	}
	if c.roc4_period <= 0 {
		return error('KST ROC4 period must be greater than 0')
	}
	if c.sma1_period <= 0 {
		return error('KST SMA1 period must be greater than 0')
	}
	if c.sma2_period <= 0 {
		return error('KST SMA2 period must be greater than 0')
	}
	if c.sma3_period <= 0 {
		return error('KST SMA3 period must be greater than 0')
	}
	if c.sma4_period <= 0 {
		return error('KST SMA4 period must be greater than 0')
	}
	if c.signal_period <= 0 {
		return error('KST signal period must be greater than 0')
	}
	return c
}

// Coppock Curve Configuration
pub struct CoppockConfig {
pub:
	roc1_period int = 14
	roc2_period int = 11
	wma_period  int = 10
}

pub fn (c CoppockConfig) validate() !CoppockConfig {
	if c.roc1_period <= 0 {
		return error('Coppock ROC1 period must be greater than 0')
	}
	if c.roc2_period <= 0 {
		return error('Coppock ROC2 period must be greater than 0')
	}
	if c.wma_period <= 0 {
		return error('Coppock WMA period must be greater than 0')
	}
	return c
}

// Vortex Indicator Configuration
pub struct VortexConfig {
pub:
	period int = 14
}

pub fn (c VortexConfig) validate() !VortexConfig {
	if c.period <= 0 {
		return error('Vortex period must be greater than 0')
	}
	return c
}

// Chaikin Money Flow Configuration
pub struct CMFConfig {
pub:
	period int = 20
}

pub fn (c CMFConfig) validate() !CMFConfig {
	if c.period <= 0 {
		return error('CMF period must be greater than 0')
	}
	return c
}

// Hull Moving Average Configuration
pub struct HMAConfig {
pub:
	period int = 20
}

pub fn (c HMAConfig) validate() !HMAConfig {
	if c.period <= 0 {
		return error('HMA period must be greater than 0')
	}
	return c
}

// Linear Regression Configuration
pub struct LinearRegressionConfig {
pub:
	period int = 20
}

pub fn (c LinearRegressionConfig) validate() !LinearRegressionConfig {
	if c.period <= 0 {
		return error('Linear Regression period must be greater than 0')
	}
	return c
}

// Volume Weighted Moving Average Configuration
pub struct VWMAConfig {
pub:
	period int = 20
}

pub fn (c VWMAConfig) validate() !VWMAConfig {
	if c.period <= 0 {
		return error('VWMA period must be greater than 0')
	}
	return c
}

// Double Exponential Moving Average Configuration
pub struct DEMAConfig {
pub:
	period int = 20
}

pub fn (c DEMAConfig) validate() !DEMAConfig {
	if c.period <= 0 {
		return error('DEMA period must be greater than 0')
	}
	return c
}

// Triple Exponential Moving Average Configuration
pub struct TEMAConfig {
pub:
	period int = 20
}

pub fn (c TEMAConfig) validate() !TEMAConfig {
	if c.period <= 0 {
		return error('TEMA period must be greater than 0')
	}
	return c
}

// Adaptive Moving Average Configuration
pub struct AMAConfig {
pub:
	fast_period int = 2
	slow_period int = 30
}

pub fn (c AMAConfig) validate() !AMAConfig {
	if c.fast_period <= 0 {
		return error('AMA fast period must be greater than 0')
	}
	if c.slow_period <= 0 {
		return error('AMA slow period must be greater than 0')
	}
	if c.fast_period >= c.slow_period {
		return error('AMA fast period must be less than slow period')
	}
	return c
}

// Arnaud Legoux Moving Average Configuration
pub struct ALMAConfig {
pub:
	period int = 20
	sigma  f64 = 6.0
	offset f64 = 0.85
}

pub fn (c ALMAConfig) validate() !ALMAConfig {
	if c.period <= 0 {
		return error('ALMA period must be greater than 0')
	}
	if c.sigma <= 0 {
		return error('ALMA sigma must be greater than 0')
	}
	if c.offset < 0 || c.offset > 1 {
		return error('ALMA offset must be between 0 and 1')
	}
	return c
}

// Momentum Configuration
pub struct MomentumConfig {
pub:
	period int = 10
}

pub fn (c MomentumConfig) validate() !MomentumConfig {
	if c.period <= 0 {
		return error('Momentum period must be greater than 0')
	}
	return c
}

// Price Rate of Change Configuration
pub struct PROCConfig {
pub:
	period int = 10
}

pub fn (c PROCConfig) validate() !PROCConfig {
	if c.period <= 0 {
		return error('PROC period must be greater than 0')
	}
	return c
}

// Detrended Price Oscillator Configuration
pub struct DPOConfig {
pub:
	period int = 20
}

pub fn (c DPOConfig) validate() !DPOConfig {
	if c.period <= 0 {
		return error('DPO period must be greater than 0')
	}
	return c
}

// Percentage Price Oscillator Configuration
pub struct PPOConfig {
pub:
	fast_period int = 12
	slow_period int = 26
	signal_period int = 9
}

pub fn (c PPOConfig) validate() !PPOConfig {
	if c.fast_period <= 0 {
		return error('PPO fast period must be greater than 0')
	}
	if c.slow_period <= 0 {
		return error('PPO slow period must be greater than 0')
	}
	if c.signal_period <= 0 {
		return error('PPO signal period must be greater than 0')
	}
	if c.fast_period >= c.slow_period {
		return error('PPO fast period must be less than slow period')
	}
	return c
}

// Chande Momentum Oscillator Configuration
pub struct CMOConfig {
pub:
	period int = 14
}

pub fn (c CMOConfig) validate() !CMOConfig {
	if c.period <= 0 {
		return error('CMO period must be greater than 0')
	}
	return c
}

// Fisher Transform Configuration
pub struct FisherConfig {
pub:
	period int = 10
}

pub fn (c FisherConfig) validate() !FisherConfig {
	if c.period <= 0 {
		return error('Fisher period must be greater than 0')
	}
	return c
}



// Standard Deviation Configuration
pub struct StdDevConfig {
pub:
	period int = 20
}

pub fn (c StdDevConfig) validate() !StdDevConfig {
	if c.period <= 0 {
		return error('Standard Deviation period must be greater than 0')
	}
	return c
}

// Historical Volatility Configuration
pub struct HistoricalVolatilityConfig {
pub:
	period int = 20
}

pub fn (c HistoricalVolatilityConfig) validate() !HistoricalVolatilityConfig {
	if c.period <= 0 {
		return error('Historical Volatility period must be greater than 0')
	}
	return c
}

// Chaikin Volatility Configuration
pub struct ChaikinVolatilityConfig {
pub:
	period int = 10
}

pub fn (c ChaikinVolatilityConfig) validate() !ChaikinVolatilityConfig {
	if c.period <= 0 {
		return error('Chaikin Volatility period must be greater than 0')
	}
	return c
}

// Ulcer Index Configuration
pub struct UlcerIndexConfig {
pub:
	period int = 14
}

pub fn (c UlcerIndexConfig) validate() !UlcerIndexConfig {
	if c.period <= 0 {
		return error('Ulcer Index period must be greater than 0')
	}
	return c
}

// Gator Oscillator Configuration
pub struct GatorConfig {
pub:
	jaw_period   int = 13
	teeth_period int = 8
	lips_period  int = 5
}

pub fn (c GatorConfig) validate() !GatorConfig {
	if c.jaw_period <= 0 {
		return error('Gator jaw period must be greater than 0')
	}
	if c.teeth_period <= 0 {
		return error('Gator teeth period must be greater than 0')
	}
	if c.lips_period <= 0 {
		return error('Gator lips period must be greater than 0')
	}
	return c
}

// Volume Rate of Change Configuration
pub struct VolumeROCConfig {
pub:
	period int = 25
}

pub fn (c VolumeROCConfig) validate() !VolumeROCConfig {
	if c.period <= 0 {
		return error('Volume ROC period must be greater than 0')
	}
	return c
}

// Volume Price Trend Configuration
pub struct VPTConfig {
pub:
	period int = 14
}

pub fn (c VPTConfig) validate() !VPTConfig {
	if c.period <= 0 {
		return error('VPT period must be greater than 0')
	}
	return c
}

// Negative Volume Index Configuration
pub struct NVIConfig {
pub:
	period int = 255
}

pub fn (c NVIConfig) validate() !NVIConfig {
	if c.period <= 0 {
		return error('NVI period must be greater than 0')
	}
	return c
}

// Positive Volume Index Configuration
pub struct PVIConfig {
pub:
	period int = 255
}

pub fn (c PVIConfig) validate() !PVIConfig {
	if c.period <= 0 {
		return error('PVI period must be greater than 0')
	}
	return c
}

// Money Flow Volume Configuration
pub struct MFVConfig {
pub:
	period int = 14
}

pub fn (c MFVConfig) validate() !MFVConfig {
	if c.period <= 0 {
		return error('MFV period must be greater than 0')
	}
	return c
}

// Volume Weighted Average Price (Enhanced) Configuration
pub struct EnhancedVWAPConfig {
pub:
	period int = 20
}

pub fn (c EnhancedVWAPConfig) validate() !EnhancedVWAPConfig {
	if c.period <= 0 {
		return error('Enhanced VWAP period must be greater than 0')
	}
	return c
}

// Pivot Points Configuration
pub struct PivotPointsConfig {
pub:
	// No additional parameters needed for standard pivot points
}

pub fn (c PivotPointsConfig) validate() !PivotPointsConfig {
	return c
}

// Fibonacci Retracements Configuration
pub struct FibonacciConfig {
pub:
	lookback_period int = 20
}

pub fn (c FibonacciConfig) validate() !FibonacciConfig {
	if c.lookback_period <= 0 {
		return error('Fibonacci lookback period must be greater than 0')
	}
	return c
}

// Price Channels Configuration
pub struct PriceChannelsConfig {
pub:
	period int = 20
}

pub fn (c PriceChannelsConfig) validate() !PriceChannelsConfig {
	if c.period <= 0 {
		return error('Price Channels period must be greater than 0')
	}
	return c
}

// Andrews Pitchfork Configuration
pub struct AndrewsPitchforkConfig {
pub:
	// No additional parameters needed for Andrews Pitchfork
}

pub fn (c AndrewsPitchforkConfig) validate() !AndrewsPitchforkConfig {
	return c
}

// Volume Weighted Average Price Configuration
pub struct VWAPConfig {
pub:
	// No additional parameters needed for basic VWAP
}

pub fn (c VWAPConfig) validate() !VWAPConfig {
	return c
}

// On Balance Volume Configuration
pub struct OBVConfig {
pub:
	// No additional parameters needed for OBV
}

pub fn (c OBVConfig) validate() !OBVConfig {
	return c
}

// Accumulation Distribution Line Configuration
pub struct ADLConfig {
pub:
	// No additional parameters needed for ADL
}

pub fn (c ADLConfig) validate() !ADLConfig {
	return c
}



// =============================================================================
// DEFAULT CONFIGURATION FUNCTIONS FOR EASY USE
// =============================================================================

// Trend Indicators - Default Configurations
pub fn default_sma_config() SMAConfig {
	return SMAConfig{}
}

pub fn default_ema_config() EMAConfig {
	return EMAConfig{}
}

pub fn default_bollinger_config() BollingerConfig {
	return BollingerConfig{}
}

pub fn default_hma_config() HMAConfig {
	return HMAConfig{}
}

pub fn default_linear_regression_config() LinearRegressionConfig {
	return LinearRegressionConfig{}
}

pub fn default_vwma_config() VWMAConfig {
	return VWMAConfig{}
}

pub fn default_dema_config() DEMAConfig {
	return DEMAConfig{}
}

pub fn default_tema_config() TEMAConfig {
	return TEMAConfig{}
}

pub fn default_ama_config() AMAConfig {
	return AMAConfig{}
}

pub fn default_alma_config() ALMAConfig {
	return ALMAConfig{}
}

// Momentum Indicators - Default Configurations
pub fn default_rsi_config() RSIConfig {
	return RSIConfig{}
}

pub fn default_momentum_config() MomentumConfig {
	return MomentumConfig{}
}

pub fn default_proc_config() PROCConfig {
	return PROCConfig{}
}

pub fn default_dpo_config() DPOConfig {
	return DPOConfig{}
}

pub fn default_ppo_config() PPOConfig {
	return PPOConfig{}
}

pub fn default_cmo_config() CMOConfig {
	return CMOConfig{}
}

pub fn default_fisher_config() FisherConfig {
	return FisherConfig{}
}



// Oscillator Indicators - Default Configurations
pub fn default_stochastic_config() StochasticConfig {
	return StochasticConfig{}
}

pub fn default_williams_r_config() WilliamsRConfig {
	return WilliamsRConfig{}
}

pub fn default_awesome_oscillator_config() AwesomeOscillatorConfig {
	return AwesomeOscillatorConfig{}
}

pub fn default_ultimate_oscillator_config() UltimateOscillatorConfig {
	return UltimateOscillatorConfig{}
}

pub fn default_stochastic_rsi_config() StochasticRSIConfig {
	return StochasticRSIConfig{}
}

// Volatility Indicators - Default Configurations
pub fn default_atr_config() ATRConfig {
	return ATRConfig{}
}

pub fn default_keltner_config() KeltnerConfig {
	return KeltnerConfig{}
}

pub fn default_std_dev_config() StdDevConfig {
	return StdDevConfig{}
}

pub fn default_historical_volatility_config() HistoricalVolatilityConfig {
	return HistoricalVolatilityConfig{}
}

pub fn default_chaikin_volatility_config() ChaikinVolatilityConfig {
	return ChaikinVolatilityConfig{}
}

pub fn default_ulcer_index_config() UlcerIndexConfig {
	return UlcerIndexConfig{}
}

pub fn default_gator_config() GatorConfig {
	return GatorConfig{}
}

// Volume Indicators - Default Configurations
pub fn default_volume_roc_config() VolumeROCConfig {
	return VolumeROCConfig{}
}

pub fn default_vpt_config() VPTConfig {
	return VPTConfig{}
}

pub fn default_nvi_config() NVIConfig {
	return NVIConfig{}
}

pub fn default_pvi_config() PVIConfig {
	return PVIConfig{}
}

pub fn default_mfv_config() MFVConfig {
	return MFVConfig{}
}

pub fn default_enhanced_vwap_config() EnhancedVWAPConfig {
	return EnhancedVWAPConfig{}
}

// Support/Resistance Indicators - Default Configurations
pub fn default_pivot_points_config() PivotPointsConfig {
	return PivotPointsConfig{}
}

pub fn default_fibonacci_config() FibonacciConfig {
	return FibonacciConfig{}
}

pub fn default_price_channels_config() PriceChannelsConfig {
	return PriceChannelsConfig{}
}

pub fn default_andrews_pitchfork_config() AndrewsPitchforkConfig {
	return AndrewsPitchforkConfig{}
}

// Additional Volume Indicators - Default Configurations
pub fn default_vwap_config() VWAPConfig {
	return VWAPConfig{}
}

pub fn default_obv_config() OBVConfig {
	return OBVConfig{}
}

pub fn default_adl_config() ADLConfig {
	return ADLConfig{}
}







// Other Indicators - Default Configurations
pub fn default_adx_config() ADXConfig {
	return ADXConfig{}
}

pub fn default_macd_config() MACDConfig {
	return MACDConfig{}
}

pub fn default_parabolic_sar_config() ParabolicSARConfig {
	return ParabolicSARConfig{}
}

pub fn default_ichimoku_config() IchimokuConfig {
	return IchimokuConfig{}
}

pub fn default_cci_config() CCIConfig {
	return CCIConfig{}
}

pub fn default_trix_config() TRIXConfig {
	return TRIXConfig{}
}

pub fn default_donchian_config() DonchianConfig {
	return DonchianConfig{}
}

pub fn default_wilders_config() WildersConfig {
	return WildersConfig{}
}

pub fn default_roc_config() ROCConfig {
	return ROCConfig{}
}

pub fn default_mfi_config() MFIConfig {
	return MFIConfig{}
}

pub fn default_kst_config() KSTConfig {
	return KSTConfig{}
}

pub fn default_coppock_config() CoppockConfig {
	return CoppockConfig{}
}

pub fn default_vortex_config() VortexConfig {
	return VortexConfig{}
}

pub fn default_cmf_config() CMFConfig {
	return CMFConfig{}
}