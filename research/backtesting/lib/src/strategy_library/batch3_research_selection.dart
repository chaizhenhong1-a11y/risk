import 'mainstream_strategy_batch.dart';

/// Frozen Batch-3 hypotheses that passed the first historical expectancy gate
/// in Increment 186.
///
/// Research-only: membership here does not promote a strategy to paper/live.
/// These exact IDs are carried into robustness and side x regime segmentation
/// without changing their signal formulations.
abstract final class Batch3ResearchSelection {
  static const historicalPassIds = <String>{
    'FAILED_BREAKOUT_V2',
    'SR_RECLAIM_V2',
    'ENGULFING_REVERSAL',
    'NR7_BREAKOUT',
    'EMA_TREND_RECLAIM',
    'THREE_BAR_PULLBACK',
  };

  static List<StrategyBatchResult> selectHistoricalPass(
    Iterable<StrategyBatchResult> results,
  ) {
    return results
        .where((result) => historicalPassIds.contains(result.strategy.id))
        .toList(growable: false);
  }
}
