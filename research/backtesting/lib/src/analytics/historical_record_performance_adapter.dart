import 'package:signal_engine/signal_engine.dart';

import '../results/historical_signal_record.dart';
import 'strategy_performance_analytics.dart';

final class HistoricalStrategyPerformanceInput {
  const HistoricalStrategyPerformanceInput({
    required this.strategy,
    required this.records,
    required this.timeForObservationIndex,
  });

  final String strategy;
  final List<HistoricalSignalRecord> records;
  final DateTime Function(int observationIndex) timeForObservationIndex;
}

final class HistoricalTimedTradeOutcome {
  const HistoricalTimedTradeOutcome({
    required this.observedAt,
    required this.outcome,
  });

  final DateTime observedAt;
  final StrategyTradeOutcome outcome;
}

/// Converts frozen A/B lifecycle records directly into performance analytics.
///
/// Only triggered TP/SL terminal records are trading P/L. Pre-entry
/// invalidation/expiry records remain lifecycle diagnostics and are excluded.
///
/// The combined stream is sorted globally by the real trigger observation time
/// before analytics, so Overall max drawdown is chronological across strategies
/// instead of being distorted by strategy-grouped input order.
final class HistoricalRecordPerformanceAdapter {
  const HistoricalRecordPerformanceAdapter();

  StrategyPerformanceBreakdown analyze(
    Iterable<HistoricalStrategyPerformanceInput> inputs,
  ) {
    final timed = <HistoricalTimedTradeOutcome>[];

    for (final input in inputs) {
      for (final record in input.records) {
        final triggerIndex = record.triggeredAtObservationIndex;
        if (triggerIndex == null) continue;

        final rMultiple = switch (record.outcome) {
          HistoricalSignalRecordOutcome.takeProfitReached =>
            record.riskRewardRatio,
          HistoricalSignalRecordOutcome.stopLossReached => -1.0,
          HistoricalSignalRecordOutcome.invalidated ||
          HistoricalSignalRecordOutcome.expired => null,
        };
        if (rMultiple == null || !rMultiple.isFinite) continue;

        final side = switch (record.direction) {
          SignalCandidateDirection.buy => 'BUY',
          SignalCandidateDirection.sell => 'SELL',
          SignalCandidateDirection.noTrade => 'UNKNOWN',
        };

        timed.add(
          HistoricalTimedTradeOutcome(
            observedAt: input.timeForObservationIndex(triggerIndex),
            outcome: StrategyTradeOutcome(
              strategy: input.strategy,
              side: side,
              rMultiple: rMultiple,
            ),
          ),
        );
      }
    }

    timed.sort((a, b) => a.observedAt.compareTo(b.observedAt));
    return analyzeStrategyPerformance(timed.map((item) => item.outcome));
  }
}
