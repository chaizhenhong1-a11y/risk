import 'mainstream_strategy_batch.dart';

/// Frozen Batch-2 hypotheses that passed the first historical expectancy gate.
///
/// Research-only: membership here does not promote a strategy to paper/live.
abstract final class Batch2ResearchSelection {
  static const historicalPassIds = <String>{
    'VOL_COMPRESSION_BREAK',
    'SWEEP_STRUCTURE',
    'EMA_MEAN_REVERT',
    'INSIDE_BAR_BREAK',
  };

  static List<StrategyBatchResult> selectHistoricalPass(
    Iterable<StrategyBatchResult> results,
  ) {
    return results
        .where((result) => historicalPassIds.contains(result.strategy.id))
        .toList(growable: false);
  }
}
