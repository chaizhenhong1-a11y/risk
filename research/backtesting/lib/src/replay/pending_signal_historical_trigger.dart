import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';

import 'ready_signal_historical_state.dart';

enum HistoricalPendingTriggerDecision {
  waiting,
  triggered,
  invalidated,
  expired,
}

/// One historical CLOSED-M5 observation of a READY signal.
///
/// Ordering deliberately matches the frozen Phase 6 contract:
/// 1. advance the historical waiting count for this newly closed M5 candle
/// 2. evaluate structural invalidation / expiry
/// 3. only while still valid, evaluate Entry Zone contact
///
/// Therefore an invalidated or expired signal cannot trigger on the same candle.
final class HistoricalPendingTriggerObservation {
  const HistoricalPendingTriggerObservation({
    required this.decision,
    required this.state,
    required this.validity,
    this.trigger,
  });

  final HistoricalPendingTriggerDecision decision;
  final HistoricalReadySignalState state;
  final PendingSignalValidity validity;
  final EntryZoneTriggerAnalysis? trigger;

  bool get isTriggered =>
      decision == HistoricalPendingTriggerDecision.triggered;

  bool get canStillWait => decision == HistoricalPendingTriggerDecision.waiting;

  bool get isTerminal => !canStillWait;
}

final class HistoricalPendingSignalTriggerController {
  const HistoricalPendingSignalTriggerController({
    this.validityEvaluator = const PendingSignalValidityEvaluator(),
    this.triggerDetector = const EntryZoneTriggerDetector(),
  });

  final PendingSignalValidityEvaluator validityEvaluator;
  final EntryZoneTriggerDetector triggerDetector;

  HistoricalPendingTriggerObservation observeClosedM5Candle({
    required HistoricalReadySignalState state,
    required double structuralBoundary,
    required double candleClose,
    required double candleLow,
    required double candleHigh,
    required int maximumWaitingCandles,
  }) {
    final nextState = state.waitOneClosedM5Candle();
    final bias = _biasFor(nextState.candidate.direction);

    final validity = validityEvaluator.evaluate(
      bias: bias,
      structuralBoundary: structuralBoundary,
      candleClose: candleClose,
      waitingCandles: nextState.waitingCandles,
      maximumWaitingCandles: maximumWaitingCandles,
    );

    if (validity.state == PendingSignalValidityState.invalidated) {
      return HistoricalPendingTriggerObservation(
        decision: HistoricalPendingTriggerDecision.invalidated,
        state: nextState,
        validity: validity,
      );
    }

    if (validity.state == PendingSignalValidityState.expired) {
      return HistoricalPendingTriggerObservation(
        decision: HistoricalPendingTriggerDecision.expired,
        state: nextState,
        validity: validity,
      );
    }

    final trigger = triggerDetector.detect(
      bias: bias,
      entryZoneAnalysis: nextState.candidate.riskPlan.entryZoneAnalysis,
      candleLow: candleLow,
      candleHigh: candleHigh,
    );

    return HistoricalPendingTriggerObservation(
      decision: trigger.isTriggered
          ? HistoricalPendingTriggerDecision.triggered
          : HistoricalPendingTriggerDecision.waiting,
      state: nextState,
      validity: validity,
      trigger: trigger,
    );
  }

  TradingBias _biasFor(SignalCandidateDirection direction) =>
      switch (direction) {
        SignalCandidateDirection.buy => TradingBias.buy,
        SignalCandidateDirection.sell => TradingBias.sell,
        SignalCandidateDirection.noTrade => throw StateError(
          'A READY historical signal cannot have NO TRADE direction.',
        ),
      };
}
