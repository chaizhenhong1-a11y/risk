import 'package:signal_engine/signal_engine.dart';

/// Historical state retained once a qualified candidate reaches READY.
///
/// The state belongs to one historical candidate and survives across later M5
/// observations until a later increment explicitly resolves invalidation,
/// expiry, or Entry Zone triggering.
final class HistoricalReadySignalState {
  const HistoricalReadySignalState({
    required this.candidate,
    required this.readyAtObservationIndex,
    required this.waitingCandles,
    required this.lifecycleState,
  });

  final SignalCandidate candidate;
  final int readyAtObservationIndex;
  final int waitingCandles;
  final SignalLifecycleState lifecycleState;

  HistoricalReadySignalState waitOneClosedM5Candle() {
    if (lifecycleState != SignalLifecycleState.ready) {
      throw StateError('Only a READY historical signal can keep waiting.');
    }

    return HistoricalReadySignalState(
      candidate: candidate,
      readyAtObservationIndex: readyAtObservationIndex,
      waitingCandles: waitingCandles + 1,
      lifecycleState: lifecycleState,
    );
  }
}

/// Creates and advances the historical READY/waiting state without inventing
/// invalidation, expiry, or trigger rules.
///
/// The frozen SignalLifecycle requires adjacent forward transitions, so READY
/// creation validates the complete pre-trigger path rather than skipping
/// directly from SCANNING to READY.
final class HistoricalReadySignalController {
  const HistoricalReadySignalController({
    this.lifecycle = const SignalLifecycle(),
  });

  final SignalLifecycle lifecycle;

  HistoricalReadySignalState? start({
    required SignalCandidate candidate,
    required int observationIndex,
  }) {
    if (observationIndex < 0) {
      throw ArgumentError.value(
        observationIndex,
        'observationIndex',
        'Observation index must be >= 0.',
      );
    }

    if (!candidate.isQualified) {
      return null;
    }

    var state = SignalLifecycleState.scanning;
    for (final next in const [
      SignalLifecycleState.watching,
      SignalLifecycleState.setupForming,
      SignalLifecycleState.ready,
    ]) {
      final transition = lifecycle.transition(from: state, to: next);
      if (!transition.isAllowed) {
        throw StateError('Frozen SignalLifecycle rejected $state -> $next.');
      }
      state = next;
    }

    return HistoricalReadySignalState(
      candidate: candidate,
      readyAtObservationIndex: observationIndex,
      waitingCandles: 0,
      lifecycleState: state,
    );
  }

  HistoricalReadySignalState observeNextClosedM5Candle(
    HistoricalReadySignalState state,
  ) {
    return state.waitOneClosedM5Candle();
  }
}
