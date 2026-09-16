import 'package:signal_engine/signal_engine.dart';

import '../replay/historical_signal_lifecycle_replay.dart';

enum HistoricalSignalRecordOutcome {
  invalidated,
  expired,
  takeProfitReached,
  stopLossReached,
}

/// Immutable research record emitted only when one historical signal plan has
/// reached an unambiguous terminal state.
///
/// Ambiguous same-candle SL/TP observations are intentionally not records yet:
/// the frozen monitor keeps those signals TRIGGERED because OHLC data cannot
/// establish intrabar ordering.
final class HistoricalSignalRecord {
  const HistoricalSignalRecord({
    required this.direction,
    required this.readyAtObservationIndex,
    required this.triggeredAtObservationIndex,
    required this.terminalAtObservationIndex,
    required this.waitingCandles,
    required this.entryPrice,
    required this.stopPrice,
    required this.targetPrice,
    required this.riskRewardRatio,
    required this.setupScoreEarnedPoints,
    required this.setupScoreAvailablePoints,
    required this.outcome,
  });

  final SignalCandidateDirection direction;
  final int readyAtObservationIndex;
  final int? triggeredAtObservationIndex;
  final int terminalAtObservationIndex;
  final int waitingCandles;

  final double entryPrice;
  final double stopPrice;
  final double targetPrice;
  final double riskRewardRatio;

  final double setupScoreEarnedPoints;
  final double setupScoreAvailablePoints;

  final HistoricalSignalRecordOutcome outcome;

  bool get wasTriggered => triggeredAtObservationIndex != null;
  bool get isTakeProfit =>
      outcome == HistoricalSignalRecordOutcome.takeProfitReached;
  bool get isStopLoss =>
      outcome == HistoricalSignalRecordOutcome.stopLossReached;
}

/// Converts the frozen historical lifecycle state into a compact research
/// record. Prices/RR remain explicit inputs so this layer never invents a fill
/// policy or reconstructs hidden Risk Engine assumptions.
final class HistoricalSignalRecordBuilder {
  const HistoricalSignalRecordBuilder();

  HistoricalSignalRecord? build({
    required HistoricalSignalLifecycleState state,
    required int terminalAtObservationIndex,
    required double entryPrice,
    required double stopPrice,
    required double targetPrice,
    required double riskRewardRatio,
  }) {
    if (terminalAtObservationIndex < 0) {
      throw ArgumentError.value(
        terminalAtObservationIndex,
        'terminalAtObservationIndex',
        'Terminal observation index must be >= 0.',
      );
    }

    final outcome = switch (state.phase) {
      HistoricalSignalLifecyclePhase.invalidated =>
        HistoricalSignalRecordOutcome.invalidated,
      HistoricalSignalLifecyclePhase.expired =>
        HistoricalSignalRecordOutcome.expired,
      HistoricalSignalLifecyclePhase.takeProfitReached =>
        HistoricalSignalRecordOutcome.takeProfitReached,
      HistoricalSignalLifecyclePhase.stopLossReached =>
        HistoricalSignalRecordOutcome.stopLossReached,
      HistoricalSignalLifecyclePhase.ready ||
      HistoricalSignalLifecyclePhase.triggered => null,
    };

    if (outcome == null) {
      return null;
    }

    final candidate = state.readyState.candidate;
    final score = candidate.setupScore;

    return HistoricalSignalRecord(
      direction: candidate.direction,
      readyAtObservationIndex: state.readyState.readyAtObservationIndex,
      triggeredAtObservationIndex: state.triggeredAtObservationIndex,
      terminalAtObservationIndex: terminalAtObservationIndex,
      waitingCandles: state.readyState.waitingCandles,
      entryPrice: entryPrice,
      stopPrice: stopPrice,
      targetPrice: targetPrice,
      riskRewardRatio: riskRewardRatio,
      setupScoreEarnedPoints: score.earnedPoints,
      setupScoreAvailablePoints: score.availablePoints,
      outcome: outcome,
    );
  }
}
