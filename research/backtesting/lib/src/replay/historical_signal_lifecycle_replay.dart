import 'package:market_models/market_models.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';

import 'pending_signal_historical_trigger.dart';
import 'ready_signal_historical_state.dart';
import 'triggered_signal_historical_monitor.dart';

enum HistoricalSignalLifecyclePhase {
  ready,
  triggered,
  invalidated,
  expired,
  takeProfitReached,
  stopLossReached,
}

/// Immutable state for one historical signal plan.
///
/// It models the signal plan only. TradeForge does not infer whether the user
/// actually entered a real position.
final class HistoricalSignalLifecycleState {
  const HistoricalSignalLifecycleState({
    required this.phase,
    required this.readyState,
    this.triggeredAtObservationIndex,
    this.lastTriggeredMonitoring,
  });

  final HistoricalSignalLifecyclePhase phase;
  final HistoricalReadySignalState readyState;
  final int? triggeredAtObservationIndex;
  final HistoricalTriggeredSignalObservation? lastTriggeredMonitoring;

  bool get isTerminal =>
      phase == HistoricalSignalLifecyclePhase.invalidated ||
      phase == HistoricalSignalLifecyclePhase.expired ||
      phase == HistoricalSignalLifecyclePhase.takeProfitReached ||
      phase == HistoricalSignalLifecyclePhase.stopLossReached;
}

final class HistoricalSignalLifecycleReplay {
  const HistoricalSignalLifecycleReplay({
    this.readyController = const HistoricalReadySignalController(),
    this.pendingController = const HistoricalPendingSignalTriggerController(),
    this.triggeredMonitor = const HistoricalTriggeredSignalMonitor(),
  });

  final HistoricalReadySignalController readyController;
  final HistoricalPendingSignalTriggerController pendingController;
  final HistoricalTriggeredSignalMonitor triggeredMonitor;

  HistoricalSignalLifecycleState? start({
    required SignalCandidate candidate,
    required int observationIndex,
  }) {
    final readyState = readyController.start(
      candidate: candidate,
      observationIndex: observationIndex,
    );
    if (readyState == null) {
      return null;
    }

    return HistoricalSignalLifecycleState(
      phase: HistoricalSignalLifecyclePhase.ready,
      readyState: readyState,
    );
  }

  HistoricalSignalLifecycleState observeClosedM5Candle({
    required HistoricalSignalLifecycleState state,
    required Candle candle,
    required int observationIndex,
    required double structuralBoundary,
    required double stopPrice,
    required double targetPrice,
    required int maximumWaitingCandles,
  }) {
    if (state.isTerminal) {
      return state;
    }

    if (state.phase == HistoricalSignalLifecyclePhase.ready) {
      final pending = pendingController.observeClosedM5Candle(
        state: state.readyState,
        structuralBoundary: structuralBoundary,
        candleClose: candle.close,
        candleLow: candle.low,
        candleHigh: candle.high,
        maximumWaitingCandles: maximumWaitingCandles,
      );

      switch (pending.decision) {
        case HistoricalPendingTriggerDecision.waiting:
          return HistoricalSignalLifecycleState(
            phase: HistoricalSignalLifecyclePhase.ready,
            readyState: pending.state,
          );
        case HistoricalPendingTriggerDecision.invalidated:
          return HistoricalSignalLifecycleState(
            phase: HistoricalSignalLifecyclePhase.invalidated,
            readyState: pending.state,
          );
        case HistoricalPendingTriggerDecision.expired:
          return HistoricalSignalLifecycleState(
            phase: HistoricalSignalLifecyclePhase.expired,
            readyState: pending.state,
          );
        case HistoricalPendingTriggerDecision.triggered:
          // The trigger candle establishes TRIGGERED. TP/SL monitoring starts
          // from later closed M5 candles so the backtest never assumes an
          // intrabar fill order between Entry Zone, SL, and TP.
          return HistoricalSignalLifecycleState(
            phase: HistoricalSignalLifecyclePhase.triggered,
            readyState: pending.state,
            triggeredAtObservationIndex: observationIndex,
          );
      }
    }

    final monitoring = triggeredMonitor.observeClosedM5Candle(
      bias: _biasFor(state.readyState.candidate.direction),
      stopPrice: stopPrice,
      targetPrice: targetPrice,
      candleLow: candle.low,
      candleHigh: candle.high,
      observationIndex: observationIndex,
    );

    final phase = switch (monitoring.monitoring.outcome) {
      TriggeredSignalOutcome.takeProfitReached =>
        HistoricalSignalLifecyclePhase.takeProfitReached,
      TriggeredSignalOutcome.stopLossReached =>
        HistoricalSignalLifecyclePhase.stopLossReached,
      TriggeredSignalOutcome.monitoring =>
        HistoricalSignalLifecyclePhase.triggered,
    };

    return HistoricalSignalLifecycleState(
      phase: phase,
      readyState: state.readyState,
      triggeredAtObservationIndex: state.triggeredAtObservationIndex,
      lastTriggeredMonitoring: monitoring,
    );
  }

  TradingBias _biasFor(SignalCandidateDirection direction) =>
      switch (direction) {
        SignalCandidateDirection.buy => TradingBias.buy,
        SignalCandidateDirection.sell => TradingBias.sell,
        SignalCandidateDirection.noTrade => throw StateError(
          'A TRIGGERED historical signal cannot have NO TRADE direction.',
        ),
      };
}
