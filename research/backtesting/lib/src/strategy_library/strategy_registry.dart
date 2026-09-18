enum StrategyLifecycle { frozenProduction, researchOnly }

enum StrategyMarketFamily {
  trend,
  pullback,
  momentum,
  breakout,
  range,
  reversal,
  transition,
  volatility,
}

final class StrategyDefinition {
  const StrategyDefinition({
    required this.id,
    required this.name,
    required this.family,
    required this.lifecycle,
    required this.description,
  });

  final String id;
  final String name;
  final StrategyMarketFamily family;
  final StrategyLifecycle lifecycle;
  final String description;
}

/// Central catalogue. Research entries are deliberately NOT allowed to emit
/// production BUY/SELL opportunities until expectancy + forward validation
/// promotes them in a later increment.
final class StrategyRegistry {
  const StrategyRegistry();

  static const all = <StrategyDefinition>[
    StrategyDefinition(
      id: 'A',
      name: 'Strategy A',
      family: StrategyMarketFamily.trend,
      lifecycle: StrategyLifecycle.frozenProduction,
      description: 'Frozen trend strategy',
    ),
    StrategyDefinition(
      id: 'C5',
      name: 'Strategy C5',
      family: StrategyMarketFamily.transition,
      lifecycle: StrategyLifecycle.frozenProduction,
      description: 'Frozen transition strategy',
    ),
    StrategyDefinition(
      id: 'EMA_TREND',
      name: 'EMA Trend',
      family: StrategyMarketFamily.trend,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'EMA 20/50 trend alignment',
    ),
    StrategyDefinition(
      id: 'EMA_CROSS',
      name: 'EMA Crossover',
      family: StrategyMarketFamily.trend,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Fast/slow EMA crossover',
    ),
    StrategyDefinition(
      id: 'MACD_TREND',
      name: 'MACD Trend',
      family: StrategyMarketFamily.trend,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'MACD trend continuation',
    ),
    StrategyDefinition(
      id: 'MACD_MOMENTUM',
      name: 'MACD Momentum',
      family: StrategyMarketFamily.momentum,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'MACD momentum expansion',
    ),
    StrategyDefinition(
      id: 'RSI_MOMENTUM',
      name: 'RSI Momentum',
      family: StrategyMarketFamily.momentum,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'RSI momentum continuation',
    ),
    StrategyDefinition(
      id: 'RSI_REVERSAL',
      name: 'RSI Reversal',
      family: StrategyMarketFamily.reversal,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'RSI extreme + reversal context',
    ),
    StrategyDefinition(
      id: 'BB_RANGE',
      name: 'Bollinger Range',
      family: StrategyMarketFamily.range,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Bollinger range mean reversion',
    ),
    StrategyDefinition(
      id: 'BB_SQUEEZE',
      name: 'Bollinger Squeeze',
      family: StrategyMarketFamily.volatility,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Compression to expansion',
    ),
    StrategyDefinition(
      id: 'ADX_TREND',
      name: 'ADX Trend',
      family: StrategyMarketFamily.trend,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Directional trend-strength setup',
    ),
    StrategyDefinition(
      id: 'DONCHIAN_BREAKOUT',
      name: 'Donchian Breakout',
      family: StrategyMarketFamily.breakout,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Channel breakout',
    ),
    StrategyDefinition(
      id: 'SR_BREAKOUT',
      name: 'S/R Breakout',
      family: StrategyMarketFamily.breakout,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Support/resistance breakout',
    ),
    StrategyDefinition(
      id: 'BREAKOUT_RETEST',
      name: 'Breakout Retest',
      family: StrategyMarketFamily.breakout,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Breakout followed by retest',
    ),
    StrategyDefinition(
      id: 'TREND_PULLBACK',
      name: 'Trend Pullback',
      family: StrategyMarketFamily.pullback,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Trend continuation after pullback',
    ),
    StrategyDefinition(
      id: 'MOMENTUM_CONT',
      name: 'Momentum Continuation',
      family: StrategyMarketFamily.momentum,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Strong directional continuation',
    ),
    StrategyDefinition(
      id: 'ATR_EXPANSION',
      name: 'ATR Expansion',
      family: StrategyMarketFamily.volatility,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Volatility expansion',
    ),
    StrategyDefinition(
      id: 'LIQ_SWEEP',
      name: 'Liquidity Sweep',
      family: StrategyMarketFamily.reversal,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Sweep / SFP reversal',
    ),
    StrategyDefinition(
      id: 'CHOCH_BOS',
      name: 'CHoCH / BOS',
      family: StrategyMarketFamily.transition,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Market-structure transition',
    ),
    StrategyDefinition(
      id: 'FAILED_BREAKOUT',
      name: 'Failed Breakout',
      family: StrategyMarketFamily.reversal,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Failed range break returning inside structure',
    ),
    StrategyDefinition(
      id: 'VOL_COMPRESSION_BREAK',
      name: 'Volatility Compression Break',
      family: StrategyMarketFamily.volatility,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Low-range compression followed by directional expansion',
    ),
    StrategyDefinition(
      id: 'SR_RECLAIM',
      name: 'S/R Reclaim',
      family: StrategyMarketFamily.transition,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Loss and reclaim of recent support/resistance',
    ),
    StrategyDefinition(
      id: 'IMPULSE_PULLBACK',
      name: 'Impulse Pullback',
      family: StrategyMarketFamily.pullback,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Pullback continuation after an ATR-sized impulse',
    ),
    StrategyDefinition(
      id: 'SWEEP_STRUCTURE',
      name: 'Sweep + Structure',
      family: StrategyMarketFamily.reversal,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Liquidity sweep with short-term structure confirmation',
    ),
    StrategyDefinition(
      id: 'EMA_MEAN_REVERT',
      name: 'EMA Mean Reversion',
      family: StrategyMarketFamily.range,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Range extension reverting toward EMA20',
    ),
    StrategyDefinition(
      id: 'INSIDE_BAR_BREAK',
      name: 'Inside Bar Break',
      family: StrategyMarketFamily.breakout,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Inside-bar compression followed by directional break',
    ),
    StrategyDefinition(
      id: 'TWO_BAR_MOMENTUM',
      name: 'Two-Bar Momentum',
      family: StrategyMarketFamily.momentum,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Two consecutive directional expansion candles',
    ),
    StrategyDefinition(
      id: 'FAILED_BREAKOUT_V2',
      name: 'Failed Breakout V2',
      family: StrategyMarketFamily.reversal,
      lifecycle: StrategyLifecycle.researchOnly,
      description:
          'Prior-bar range break fails, then confirmation closes away from the failed level',
    ),
    StrategyDefinition(
      id: 'SR_RECLAIM_V2',
      name: 'S/R Reclaim V2',
      family: StrategyMarketFamily.transition,
      lifecycle: StrategyLifecycle.researchOnly,
      description:
          'Prior close loses a pre-existing level and current bar reclaims it',
    ),
    StrategyDefinition(
      id: 'PIN_BAR_REVERSAL',
      name: 'Pin Bar Reversal',
      family: StrategyMarketFamily.reversal,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Long rejection wick at a recent range extreme',
    ),
    StrategyDefinition(
      id: 'ENGULFING_REVERSAL',
      name: 'Engulfing Reversal',
      family: StrategyMarketFamily.reversal,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Directional body engulf after an opposing candle',
    ),
    StrategyDefinition(
      id: 'NR7_BREAKOUT',
      name: 'NR7 Breakout',
      family: StrategyMarketFamily.volatility,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Breakout after the narrowest prior candle of seven bars',
    ),
    StrategyDefinition(
      id: 'EMA_TREND_RECLAIM',
      name: 'EMA Trend Reclaim',
      family: StrategyMarketFamily.pullback,
      lifecycle: StrategyLifecycle.researchOnly,
      description:
          'Trend pullback closes back through EMA20 with EMA20/50 alignment',
    ),
    StrategyDefinition(
      id: 'VOL_SPIKE_FADE',
      name: 'Volatility Spike Fade',
      family: StrategyMarketFamily.reversal,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Fade a prior oversized candle after failure to continue',
    ),
    StrategyDefinition(
      id: 'THREE_BAR_PULLBACK',
      name: 'Three-Bar Pullback',
      family: StrategyMarketFamily.pullback,
      lifecycle: StrategyLifecycle.researchOnly,
      description:
          'Three-bar counter-trend pullback followed by trend resumption',
    ),
    StrategyDefinition(
      id: 'RANGE_REJECTION',
      name: 'Range Rejection',
      family: StrategyMarketFamily.range,
      lifecycle: StrategyLifecycle.researchOnly,
      description: 'Range boundary rejection',
    ),
  ];

  List<StrategyDefinition> get production => List.unmodifiable(
    all.where((s) => s.lifecycle == StrategyLifecycle.frozenProduction),
  );
  List<StrategyDefinition> get research => List.unmodifiable(
    all.where((s) => s.lifecycle == StrategyLifecycle.researchOnly),
  );
}
