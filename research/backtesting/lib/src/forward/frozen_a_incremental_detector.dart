import 'package:market_models/market_models.dart';
import 'package:signal_engine/signal_engine.dart';

import '../replay/historical_signal_lifecycle_replay.dart';
import 'frozen_a_triggered_paper_adapter.dart';
import 'paper_strategy_opportunity.dart';

/// Incremental Strategy A lifecycle for live CLOSED M5 observations.
///
/// Candidate construction remains owned by the already-frozen Strategy A
/// Strategy -> Risk -> SignalCandidate pipeline. This class only preserves the
/// frozen READY -> TRIGGERED lifecycle across later unseen candles and emits
/// exactly once on the real trigger transition.
final class FrozenAIncrementalDetector {
  FrozenAIncrementalDetector({
    this.maximumWaitingCandles = 12,
    HistoricalSignalLifecycleReplay? lifecycleReplay,
    FrozenATriggeredPaperAdapter? adapter,
  }) : lifecycleReplay =
           lifecycleReplay ?? const HistoricalSignalLifecycleReplay(),
       adapter = adapter ?? const FrozenATriggeredPaperAdapter();

  final int maximumWaitingCandles;
  final HistoricalSignalLifecycleReplay lifecycleReplay;
  final FrozenATriggeredPaperAdapter adapter;

  HistoricalSignalLifecycleState? _state;
  int _observationIndex = -1;

  HistoricalSignalLifecycleState? get state => _state;
  bool get hasActivePlan => _state != null && !_state!.isTerminal;

  PaperStrategyOpportunity? observe({
    required Candle closedM5,
    required DateTime observedAt,
    SignalCandidate? candidate,
  }) {
    _observationIndex++;

    final current = _state;
    if (current != null && !current.isTerminal) {
      final plan = current.readyState.candidate.riskPlan;
      final structuralStop = plan.structuralStopAnalysis.stop;
      final protectiveStop = plan.protectiveStopAnalysis.stop;
      final rr = plan.riskRewardAnalysis.riskReward;
      if (structuralStop == null || protectiveStop == null || rr == null) {
        throw StateError('Frozen Strategy A active plan lost risk geometry.');
      }

      final previousPhase = current.phase;
      final next = lifecycleReplay.observeClosedM5Candle(
        state: current,
        candle: closedM5,
        observationIndex: _observationIndex,
        structuralBoundary: structuralStop.price,
        stopPrice: protectiveStop.price,
        targetPrice: rr.targetPrice,
        maximumWaitingCandles: maximumWaitingCandles,
      );
      _state = next;

      if (previousPhase != HistoricalSignalLifecyclePhase.triggered &&
          next.phase == HistoricalSignalLifecyclePhase.triggered) {
        return adapter.convert(lifecycle: next, triggeredAt: observedAt);
      }

      // Preserve the frozen one-plan lifecycle. A terminal candle is not reused
      // to start another Strategy A plan.
      if (next.isTerminal) {
        _state = null;
      }
      return null;
    }

    if (candidate == null || !candidate.isQualified) return null;

    _state = lifecycleReplay.start(
      candidate: candidate,
      observationIndex: _observationIndex,
    );
    return null;
  }
}
