import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';

import 'ready_signal_historical_state.dart';

enum HistoricalPendingSignalDecision { waiting, invalidated, expired }

/// Result of observing one later CLOSED M5 candle while a historical signal is
/// still READY.
///
/// This increment deliberately stops before Entry Zone triggering. The frozen
/// PendingSignalValidityEvaluator remains authoritative for structure
/// invalidation and expiry, including invalidation priority when both conditions
/// become true on the same candle.
final class HistoricalPendingSignalObservation {
  const HistoricalPendingSignalObservation({
    required this.decision,
    required this.state,
    required this.validity,
  });

  final HistoricalPendingSignalDecision decision;
  final HistoricalReadySignalState state;
  final PendingSignalValidity validity;

  bool get canStillWait => decision == HistoricalPendingSignalDecision.waiting;
  bool get isTerminal => !canStillWait;
}

final class HistoricalPendingSignalValidityController {
  const HistoricalPendingSignalValidityController({
    this.validityEvaluator = const PendingSignalValidityEvaluator(),
  });

  final PendingSignalValidityEvaluator validityEvaluator;

  HistoricalPendingSignalObservation observeClosedM5Candle({
    required HistoricalReadySignalState state,
    required double structuralBoundary,
    required double candleClose,
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

    final decision = switch (validity.state) {
      PendingSignalValidityState.valid =>
        HistoricalPendingSignalDecision.waiting,
      PendingSignalValidityState.invalidated =>
        HistoricalPendingSignalDecision.invalidated,
      PendingSignalValidityState.expired =>
        HistoricalPendingSignalDecision.expired,
    };

    return HistoricalPendingSignalObservation(
      decision: decision,
      state: nextState,
      validity: validity,
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
